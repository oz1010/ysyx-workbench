import chisel3._
import circt.stage.ChiselStage

import java.nio.charset.StandardCharsets
import java.nio.file.{Files, Path, Paths}
import scala.jdk.CollectionConverters._
import scala.util.matching.Regex

/** Discover Module classes in *.scala files and emit one Verilog file per class. */
object Generate {
  private val modulePattern: Regex =
    "(?m)\\bclass\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?:\\([^)]*\\))?\\s+extends\\s+Module\\b".r

  private val packagePattern: Regex =
    "(?m)^\\s*package\\s+([A-Za-z_][A-Za-z0-9_.]*)\\s*$".r

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

  def main(args: Array[String]): Unit = {
    val root = Paths.get(".").toAbsolutePath.normalize()
    val sourceRoot = root.resolve("src")
    val outRoot = root.resolve(if (args.nonEmpty) args(0) else "build")
    Files.createDirectories(outRoot)

    val modules = sourceModules(sourceRoot)
    require(modules.nonEmpty, s"No Module classes found below $sourceRoot")

    modules.foreach { case (source, fqcn) =>
      val relative = sourceRoot.relativize(source)
      val simple = fqcn.substring(fqcn.lastIndexOf('.') + 1)
      val targetDir = Option(relative.getParent).map(outRoot.resolve).getOrElse(outRoot)
      Files.createDirectories(targetDir)
      val target = targetDir.resolve(s"$simple.v")
      try {
        val verilog = ChiselStage.emitSystemVerilog(
          instantiate(fqcn),
          firtoolOpts = Array("--disable-layers=Verification")
        )
        Files.writeString(target, verilog, StandardCharsets.UTF_8)
        println(s"[chisel] $relative :: $simple -> ${outRoot.relativize(target)}")
      } catch {
        case t: Throwable =>
          System.err.println(s"[chisel] skip $relative :: $simple (${t.getClass.getSimpleName}: ${t.getMessage})")
      }
    }
  }
}
