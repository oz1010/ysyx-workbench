import chisel3._
import circt.stage.ChiselStage

import java.lang.reflect.InvocationTargetException
import java.nio.charset.StandardCharsets
import java.nio.file.{Files, Path, Paths, StandardCopyOption}
import scala.collection.mutable
import scala.jdk.CollectionConverters._
import scala.util.control.NonFatal
import scala.util.matching.Regex

/** 遍历指定 src 目录及 common，无需指定顶层：
  *   - 发现 Module/RawModule 类并逐类生成，BlackBox 随所属模块处理，优先保留完整层级，按完整模块名全局去重；
  *   - 按类名拆分输出，参数化变体归入基类文件，辅助模块归入当前生成类的文件；
  *   - .v/.sv 手写 Verilog 保持相对路径原样拷贝，不编译、不改写；
  *   - 不对外设模块做特殊处理。
  * 参数：args(0) 输出根目录（默认 build），args(1) 源目录名（默认 pipeline-manual）。
  */
object Generate {
  private val modulePattern: Regex =
    "(?m)\\bclass\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?:\\([^)]*\\))?\\s+extends\\s+((?:Raw)?Module)\\b".r

  private val packagePattern: Regex =
    "(?m)^\\s*package\\s+([A-Za-z_][A-Za-z0-9_.]*)\\s*$".r

  private def sourceFiles(roots: Seq[Path]): Seq[Path] =
    roots.distinct.filter(Files.isDirectory(_)).flatMap { root =>
      val stream = Files.walk(root)
      try stream.iterator().asScala.filter(Files.isRegularFile(_)).toVector
      finally stream.close()
    }.distinct.sortBy(_.toString)

  private def sourceModules(files: Seq[Path]): Seq[(Path, String)] = {
    files
      .filter(_.toString.endsWith(".scala"))
      .flatMap { file =>
        val text = Files.readString(file)
        val pkg  = packagePattern
          .findFirstMatchIn(text)
          .map(m => m.group(1) + ".")
          .getOrElse("")
        modulePattern
          .findAllMatchIn(text)
          .map(m => file -> (pkg + m.group(1)))
          .toSeq
      }
      .sortBy { case (file, name) => (file.toString, name) }
  }

  private def caseClassInstance(cls: Class[_]): AnyRef = {
    val companion =
      Class.forName(cls.getName + "$").getField("MODULE$").get(null)
    val apply     = companion.getClass.getMethods
      .filter(m => m.getName == "apply" && !m.isSynthetic)
      .find(
        _.getParameterCount == companion.getClass.getMethods
          .count(_.getName.startsWith("apply$default$"))
      )
      .getOrElse(
        sys.error(s"No all-default apply found on companion of ${cls.getName}")
      )
    val args      = (1 to apply.getParameterCount).map(i =>
      companion.getClass.getMethod(s"apply$$default$$$i").invoke(companion)
    )
    apply.invoke(companion, args: _*)
  }

  private def defaultArg(ptype: Class[_], owner: String): AnyRef = ptype match {
    case t if t == classOf[Int]                    => Int.box(2)
    case t if t == classOf[Boolean]                => Boolean.box(true)
    case t if classOf[Product].isAssignableFrom(t) => caseClassInstance(t)
    case t                                         =>
      sys.error(
        s"No default value for constructor parameter of type ${t.getName} in $owner"
      )
  }

  private def instantiate(fqcn: String): RawModule = {
    val cls       = Class.forName(fqcn)
    val ctor      = cls.getConstructors.maxBy(_.getParameterCount)
    val companion = try {
      Some(Class.forName(fqcn + "$").getField("MODULE$").get(null))
    } catch {
      case _: ClassNotFoundException => None
    }
    val args      = ctor.getParameterTypes.zipWithIndex.map { case (ptype, index) =>
      val default = companion.flatMap { instance =>
        instance.getClass.getMethods
          .find(_.getName == s"$$lessinit$$greater$$default$$${index + 1}")
          .map(_.invoke(instance))
      }
      default.getOrElse(defaultArg(ptype, fqcn))
    }
    ctor.newInstance(args: _*).asInstanceOf[RawModule]
  }

  /** 顶层适配：Chisel 无法把 Scala 构造参数导出为 Verilog parameter， 这里对指定顶层在生成文本上注入
    * parameter，使生成代码与 vsrc/core/ysyx_23060295.v 中
    * `riscv32e_core #(.INST_WIDTH(...))` 的 例化方式保持兼容。
    */
  private val topParams: Map[String, Seq[String]] = Map(
    "riscv32e_core" -> Seq("INST_WIDTH = 32")
  )

  private def adaptTop(name: String, verilog: String): String = {
    val params = topParams.getOrElse(name, Seq.empty)
    if (params.isEmpty) verilog
    else {
      val paramBlock = params.map(p => s"    parameter $p").mkString(",\n")
      val withParams = verilog.replaceFirst(
        s"(?m)^module ${Regex.quote(name)}\\(",
        s"module $name #(\n$paramBlock\n) ("
      )
      require(
        withParams ne verilog,
        s"fail to inject parameters into module $name"
      )
      // pc 端口宽度跟随 INST_WIDTH（与手写核一致）
      withParams.replaceFirst(
        "(?m)^(\\s*output\\s+)\\[31:0\\](\\s+pc\\b)",
        "$1[INST_WIDTH-1:0]$2"
      )
    }
  }

  private def emitVerilog(fqcn: String): String =
    ChiselStage.emitSystemVerilog(
      instantiate(fqcn),
      // disallowLocalVariables: 不在 always 块内生成 automatic 局部变量，
      // 保证 yosys (make sta-area) 能解析生成代码。
      // --preserve-aggregate=all: 保持 Vec/Bundle 等聚合数据类型结构，不被打平为独立的 x_0, x_1 标量信号
      // TODO 计算面积时，不能将聚合数据展开；或改用Verilog主动推送修改项；
      firtoolOpts = Array(
        "--disable-layers=Verification",
        "--lowering-options=disallowLocalVariables",
        "--preserve-aggregate=all",
        // 顶层端口会被展平，内部端口也采用相同形式，避免独立生成后接口不一致。
        "--scalarize-internal-modules"
      )
    )

  private val moduleStart: Regex =
    "(?m)^module\\s+([A-Za-z_][A-Za-z0-9_]*)\\b".r

  private val verilogComments: Regex =
    "(?s)/\\*.*?\\*/|//[^\\r\\n]*|\"(?:\\\\.|[^\"\\\\])*\"".r

  private val handwrittenModule: Regex =
    "\\bmodule\\s+(?:(?:automatic|static)\\s+)?([A-Za-z_][A-Za-z0-9_$]*)".r

  /** 把一次编译出的 Verilog 切成 (文件头, [(模块名, 模块文本)])，文件头含宏定义，需写进每个文件。 */
  private def splitModules(verilog: String): (String, Seq[(String, String)]) = {
    val starts   = moduleStart.findAllMatchIn(verilog).toSeq
    require(starts.nonEmpty, "no module emitted")
    val preamble = verilog.substring(0, starts.head.start)
    val chunks   = starts.map { m =>
      val end     = verilog.indexOf("endmodule", m.end)
      require(end >= 0, s"endmodule not found for module ${m.group(1)}")
      val lineEnd = verilog.indexOf('\n', end) match {
        case -1  => verilog.length
        case idx => idx + 1
      }
      m.group(1) -> verilog.substring(m.start, lineEnd)
    }
    preamble -> chunks
  }

  /** Cache_1 这类带参数后缀的变体模块归入基类文件。 */
  private val paramSuffix: Regex = "_\\d+$".r

  def main(args: Array[String]): Unit = {
    val root       = Paths.get(".").toAbsolutePath.normalize()
    val sourceRoot = root.resolve("src")
    val outRoot    = root.resolve(if (args.nonEmpty) args(0) else "build")
    // 生成目标目录名（如 pipeline-manual）：只编译该目录 + common 下的源文件
    val genName    = if (args.length > 1) args(1) else "pipeline-manual"
    val sourceDirs = Seq(sourceRoot.resolve(genName), sourceRoot.resolve("common"))
    require(
      Files.isDirectory(sourceDirs.head),
      s"source directory does not exist or is not a directory: ${sourceDirs.head}"
    )
    Files.createDirectories(outRoot)

    val files   = sourceFiles(sourceDirs)
    val modules = sourceModules(files)

    def targetFor(source: Path, fqcn: String): Path = {
      val relative  = sourceRoot.relativize(source)
      val simple    = fqcn.substring(fqcn.lastIndexOf('.') + 1)
      val targetDir =
        Option(relative.getParent).map(outRoot.resolve).getOrElse(outRoot)
      Files.createDirectories(targetDir)
      targetDir.resolve(s"$simple.v")
    }

    val claimed = mutable.Set.empty[String]
    // 手写模块名也参与去重；文件本身不编译、不改写，不能被生成文件覆盖。
    val copied = files
      .filter(p => p.toString.endsWith(".v") || p.toString.endsWith(".sv"))
      .map { source =>
        val text = verilogComments.replaceAllIn(Files.readString(source), " ")
        handwrittenModule.findAllMatchIn(text).foreach { m =>
          require(
            claimed.add(m.group(1)),
            s"duplicate handwritten module ${m.group(1)} in $source"
          )
        }
        val relative = sourceRoot.relativize(source)
        val target   = outRoot.resolve(relative)
        Option(target.getParent).foreach(Files.createDirectories(_))
        Files.copy(source, target, StandardCopyOption.REPLACE_EXISTING)
        println(s"[chisel] $relative :: copy -> ${outRoot.relativize(target)}")
        target
      }
      .toSet

    val classFile = modules.map { case (source, fqcn) =>
      fqcn.substring(fqcn.lastIndexOf('.') + 1) -> targetFor(source, fqcn)
    }.toMap
    val routed    =
      mutable.LinkedHashMap.empty[Path, mutable.ArrayBuffer[(String, String)]]

    val failures = mutable.ArrayBuffer.empty[(String, Throwable)]
    val emitted = modules.filterNot { case (_, fqcn) =>
      claimed(fqcn.substring(fqcn.lastIndexOf('.') + 1))
    }.flatMap { case (source, fqcn) =>
      try {
        val (preamble, chunks) = splitModules(emitVerilog(fqcn))
        Some((source, fqcn, preamble, chunks))
      } catch {
        case NonFatal(t) =>
          val cause = t match {
            case e: InvocationTargetException if e.getCause != null => e.getCause
            case _ => t
          }
          failures += fqcn -> cause
          System.err.println(
            s"[chisel] failed $source :: $fqcn (${cause.getClass.getSimpleName}: ${cause.getMessage})"
          )
          None
      }
    }
    require(
      failures.isEmpty,
      s"Verilog generation failed for: ${failures.map(_._1).mkString(", ")}"
    )

    // 优先保留完整层级，避免独立生成的默认参数版本抢占层级内的同名子模块。
    emitted.sortBy { case (source, fqcn, _, chunks) =>
      (-chunks.size, source.toString, fqcn)
    }.foreach { case (source, fqcn, preamble, chunks) =>
      chunks.foreach { case (name, body) =>
        if (claimed.add(name)) {
          val target = classFile.getOrElse(
            name,
            classFile.getOrElse(
              paramSuffix.replaceFirstIn(name, ""),
              targetFor(source, fqcn)
            )
          )
          require(
            !copied(target),
            s"generated file would overwrite handwritten Verilog: $target"
          )
          routed.getOrElseUpdate(target, mutable.ArrayBuffer.empty) +=
            preamble -> adaptTop(name, body)
          println(
            s"[chisel] ${sourceRoot.relativize(source)} :: $name -> ${outRoot.relativize(target)}"
          )
        }
      }
    }

    // 每个文件保留其模块各次编译的文件头，不能借用某个固定顶层的文件头。
    routed.foreach { case (target, chunks) =>
      val preamble = chunks.map(_._1).distinct.mkString
      val bodies   = chunks.map(_._2).mkString("\n")
      Files.writeString(target, preamble + bodies, StandardCharsets.UTF_8)
    }
  }
}
