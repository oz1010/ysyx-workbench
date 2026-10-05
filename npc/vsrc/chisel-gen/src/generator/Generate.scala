import chisel3._
import circt.stage.ChiselStage

import java.nio.charset.StandardCharsets
import java.nio.file.{Files, Path, Paths}
import scala.collection.mutable
import scala.jdk.CollectionConverters._
import scala.util.matching.Regex

/**
 * 顶层单次编译，按模块拆分输出：
 *   - 先对顶层 riscv32e_core 做一次 emitSystemVerilog，整个层级只编译一次，
 *     子模块（Cache/Lsu/...）不会因为逐类独立编译而在多个文件里重复定义，
 *     保证 yosys (make sta-area) 读入全部 *.v 时不报 "Re-definition of module"；
 *   - 按模块名把每个 module 拆到对应类的输出文件（Cache_1 这类参数化变体
 *     归入基类文件），匿名辅助模块并入顶层文件；
 *   - flash/sram/rom/sdram/psram 等外设存储器阵列改写到 srams.v，面积综合
 *     （IN_YOSYS_STA）下只生成 (* blackbox *) 空壳，不计入芯片面积；
 *     cache 内部的 tagMem/dataMem 等核内存储阵列随核逻辑正常综合，计入芯片面积；
 *   - 不在顶层层级中的其余类仍按原来的逐类独立编译输出。
 */
object Generate {
  private val modulePattern: Regex =
    "(?m)\\bclass\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?:\\([^)]*\\))?\\s+extends\\s+(?:Raw)?Module\\b".r

  private val packagePattern: Regex =
    "(?m)^\\s*package\\s+([A-Za-z_][A-Za-z0-9_.]*)\\s*$".r

  /** 顶层全层级编译的入口类（对外适配层，端口与手写核例化保持一致）。 */
  private val topFqcn = "pipeline_chisel.riscv32e_core"

  private def sourceModules(root: Path): Seq[(Path, String)] = {
    Files.walk(root).iterator().asScala
      .filter(p => Files.isRegularFile(p) && p.toString.endsWith(".scala"))
      .toSeq
      .flatMap { file =>
        val text = Files.readString(file)
        val pkg = packagePattern.findFirstMatchIn(text).map(m => m.group(1) + ".").getOrElse("")
        modulePattern.findAllMatchIn(text).map(m => file -> (pkg + m.group(1))).toSeq
      }
      .sortBy { case (file, name) => (file.toString, name) }
  }

  private def caseClassInstance(cls: Class[_]): AnyRef = {
    val companion = Class.forName(cls.getName + "$").getField("MODULE$").get(null)
    val apply = companion.getClass.getMethods
      .filter(m => m.getName == "apply" && !m.isSynthetic)
      .find(_.getParameterCount == companion.getClass.getMethods.count(_.getName.startsWith("apply$default$")))
      .getOrElse(sys.error(s"No all-default apply found on companion of ${cls.getName}"))
    val args = (1 to apply.getParameterCount).map(i =>
      companion.getClass.getMethod(s"apply$$default$$$i").invoke(companion))
    apply.invoke(companion, args: _*)
  }

  private def defaultArg(ptype: Class[_], owner: String): AnyRef = ptype match {
    case t if t == classOf[Int]            => Int.box(2)
    case t if t == classOf[Boolean]        => Boolean.box(true)
    case t if classOf[Product].isAssignableFrom(t) => caseClassInstance(t)
    case t => sys.error(s"No default value for constructor parameter of type ${t.getName} in $owner")
  }

  private def instantiate(fqcn: String): RawModule = {
    val cls = Class.forName(fqcn)
    val ctor = cls.getConstructors.maxBy(_.getParameterCount)
    val args = ctor.getParameterTypes.map(defaultArg(_, fqcn))
    ctor.newInstance(args: _*).asInstanceOf[RawModule]
  }

  /**
   * 顶层适配：Chisel 无法把 Scala 构造参数导出为 Verilog parameter，
   * 这里对指定顶层在生成文本上注入 parameter，使生成代码与
   * vsrc/core/ysyx_23060295.v 中 `riscv32e_core #(.INST_WIDTH(...))` 的
   * 例化方式保持兼容。
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
      require(withParams ne verilog, s"fail to inject parameters into module $name")
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
      firtoolOpts = Array("--disable-layers=Verification", "--lowering-options=disallowLocalVariables")
    )

  private val moduleStart: Regex = "(?m)^module\\s+([A-Za-z_][A-Za-z0-9_]*)\\b".r

  /** 把一次编译出的 Verilog 切成 (文件头, [(模块名, 模块文本)])，文件头含宏定义，需写进每个文件。 */
  private def splitModules(verilog: String): (String, Seq[(String, String)]) = {
    val starts = moduleStart.findAllMatchIn(verilog).toSeq
    require(starts.nonEmpty, "no module emitted")
    val preamble = verilog.substring(0, starts.head.start)
    val chunks = starts.map { m =>
      val end = verilog.indexOf("endmodule", m.end)
      require(end >= 0, s"endmodule not found for module ${m.group(1)}")
      val lineEnd = verilog.indexOf('\n', end) match {
        case -1   => verilog.length
        case idx  => idx + 1
      }
      m.group(1) -> verilog.substring(m.start, lineEnd)
    }
    preamble -> chunks
  }

  /** Cache_1 这类带参数后缀的变体模块归入基类文件。 */
  private val paramSuffix: Regex = "_\\d+$".r

  /**
   * 外设存储器阵列模块（flash/sram/rom/sdram/psram）：经总线访问的片外存储，
   * 不计入芯片面积。make sta-area 的 tcl 定义了 IN_YOSYS_STA，此时只保留端口、
   * 生成 (* blackbox *) 空壳交给 yosys；其余流程（仿真等）仍使用原始行为级实现。
   * cache 内部的 tagMem/dataMem 等核内存储不在这里匹配，随核逻辑综合并计入面积。
   */
  private val sramModule: Regex = "(?i)^(flash|sram|rom|sdram|psram)(?:_|$)".r

  private def isSramModule(name: String): Boolean = sramModule.findFirstIn(name).nonEmpty

  private def blackboxify(name: String, chunk: String): String = {
    val headerEnd = chunk.indexOf(");")
    require(headerEnd >= 0, s"fail to locate port list end of sram module $name")
    val bodyEnd = chunk.lastIndexOf("endmodule")
    require(bodyEnd > headerEnd, s"fail to locate endmodule of sram module $name")
    val header = chunk.substring(0, headerEnd + 2)
    val body = chunk.substring(headerEnd + 2, bodyEnd)
    s"`ifdef IN_YOSYS_STA\n(* blackbox *)\n`endif\n" +
      header + "\n" +
      "`ifndef IN_YOSYS_STA\n" + body + "`endif\n" +
      "endmodule\n"
  }

  def main(args: Array[String]): Unit = {
    val root = Paths.get(".").toAbsolutePath.normalize()
    val sourceRoot = root.resolve("src")
    val outRoot = root.resolve(if (args.nonEmpty) args(0) else "build")
    Files.createDirectories(outRoot)

    val modules = sourceModules(sourceRoot)
    require(modules.nonEmpty, s"No Module classes found below $sourceRoot")

    def targetFor(source: Path, fqcn: String): Path = {
      val relative = sourceRoot.relativize(source)
      val simple = fqcn.substring(fqcn.lastIndexOf('.') + 1)
      val targetDir = Option(relative.getParent).map(outRoot.resolve).getOrElse(outRoot)
      Files.createDirectories(targetDir)
      targetDir.resolve(s"$simple.v")
    }

    def writeVerilog(target: Path, preamble: String, chunks: Seq[(String, String)]): Unit = {
      val sb = new StringBuilder(preamble)
      chunks.foreach { case (_, body) => sb.append(body).append('\n') }
      Files.writeString(target, sb.toString, StandardCharsets.UTF_8)
    }

    // ---- 1) 顶层单次编译，整个层级只生成一份 ----
    val (topSource, _) = modules.find(_._2 == topFqcn)
      .getOrElse(sys.error(s"top module $topFqcn not found below $sourceRoot"))
    val topSimple = topFqcn.substring(topFqcn.lastIndexOf('.') + 1)
    val topTarget = targetFor(topSource, topFqcn)

    val (preamble, chunks) = splitModules(adaptTop(topSimple, emitVerilog(topFqcn)))
    val classFile: Map[String, Path] = modules.map { case (source, fqcn) =>
      fqcn.substring(fqcn.lastIndexOf('.') + 1) -> targetFor(source, fqcn)
    }.toMap

    val sramTarget = topTarget.getParent.resolve("srams.v")

    val routed = mutable.LinkedHashMap.empty[Path, mutable.ArrayBuffer[(String, String)]]
    chunks.foreach { case (name, body) =>
      val (target, chunk) =
        if (isSramModule(name)) (sramTarget, blackboxify(name, body))
        else (classFile.getOrElse(name,
          classFile.getOrElse(paramSuffix.replaceFirstIn(name, ""), topTarget)), body)
      routed.getOrElseUpdate(target, mutable.ArrayBuffer.empty) += name -> chunk
    }
    routed.getOrElseUpdate(topTarget, mutable.ArrayBuffer.empty)

    routed.foreach { case (target, buf) =>
      writeVerilog(target, preamble, buf.toSeq)
      println(s"[chisel] ${sourceRoot.relativize(topSource)} :: " +
        s"${buf.map(_._1).mkString("+")} -> ${outRoot.relativize(target)}")
    }

    // ---- 2) 不在顶层层级中的其余类，仍逐类独立编译 ----
    val covered = chunks.map(_._1).flatMap(n => Seq(n, paramSuffix.replaceFirstIn(n, ""))).toSet
    modules.filterNot(_._2 == topFqcn).foreach { case (source, fqcn) =>
      val simple = fqcn.substring(fqcn.lastIndexOf('.') + 1)
      if (covered(simple)) {
        println(s"[chisel] ${sourceRoot.relativize(source)} :: $simple -> covered by ${topSimple}.v")
      } else {
        val target = targetFor(source, fqcn)
        try {
          val verilog = adaptTop(simple, emitVerilog(fqcn))
          Files.writeString(target, verilog, StandardCharsets.UTF_8)
          println(s"[chisel] ${sourceRoot.relativize(source)} :: $simple -> ${outRoot.relativize(target)}")
        } catch {
          case t: Throwable =>
            System.err.println(s"[chisel] skip $source :: $simple (${t.getClass.getSimpleName}: ${t.getMessage})")
        }
      }
    }
  }
}
