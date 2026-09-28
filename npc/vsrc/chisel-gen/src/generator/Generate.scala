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

  private def sourceModules(root: Path): Seq[(Path, String)] = {
    Files.walk(root).iterator().asScala
      .filter(p => Files.isRegularFile(p) && p.toString.endsWith(".scala"))
      .toSeq
      .flatMap { file =>
        val text = Files.readString(file)
        modulePattern.findAllMatchIn(text).map(m => file -> m.group(1)).toSeq
      }
      .sortBy { case (file, name) => (file.toString, name) }
  }

  private def instantiate(name: String): RawModule = {
    val cls = Class.forName(name)
    val ctor = cls.getConstructors.find(_.getParameterCount == 0)
      .orElse(cls.getConstructors.find(c => c.getParameterCount == 1 && c.getParameterTypes.head == classOf[Int]))
      .getOrElse(sys.error(s"No supported constructor found for module $name"))
    if (ctor.getParameterCount == 0) ctor.newInstance().asInstanceOf[RawModule]
    else ctor.newInstance(Int.box(2)).asInstanceOf[RawModule]
  }

  def main(args: Array[String]): Unit = {
    val root = Paths.get(".").toAbsolutePath.normalize()
    val sourceRoot = root.resolve("src")
    val outRoot = root.resolve(if (args.nonEmpty) args(0) else "build")
    Files.createDirectories(outRoot)

    val modules = sourceModules(sourceRoot)
    require(modules.nonEmpty, s"No Module classes found below $sourceRoot")

    modules.foreach { case (source, name) =>
      val relative = sourceRoot.relativize(source)
      val targetDir = Option(relative.getParent).map(outRoot.resolve).getOrElse(outRoot)
      Files.createDirectories(targetDir)
      val target = targetDir.resolve(s"${source.getFileName.toString.stripSuffix(".scala")}_$name.v")
      try {
        val verilog = ChiselStage.emitSystemVerilog(instantiate(name))
        Files.writeString(target, verilog, StandardCharsets.UTF_8)
        println(s"[chisel] $relative :: $name -> ${outRoot.relativize(target)}")
      } catch {
        case t: Throwable =>
          System.err.println(s"[chisel] skip $relative :: $name (${t.getMessage})")
      }
    }
  }
}
