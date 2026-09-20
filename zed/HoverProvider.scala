/*
 * Copyright 2020 Magnus Madsen
 * Copyright 2026 Attune contributors
 * SPDX-License-Identifier: Apache-2.0
 *
 * Derived from Flix's HoverProvider.
 *
 * This class deliberately has the same fully-qualified name as the provider in
 * the pinned Flix jar. The Nix launcher puts this tiny patch jar first on the
 * class path, retaining Flix's LSP while filling its declaration/predicate
 * hover gaps.
 */
package ca.uwaterloo.flix.api.lsp.provider

import ca.uwaterloo.flix.api.Flix
import ca.uwaterloo.flix.api.lsp.acceptors.InsideAcceptor
import ca.uwaterloo.flix.api.lsp.consumers.StackConsumer
import ca.uwaterloo.flix.api.lsp.{Hover, MarkupContent, MarkupKind, Position, Range, Visitor}
import ca.uwaterloo.flix.language.ast.TypedAst.*
import ca.uwaterloo.flix.language.ast.shared.SymUse.{CaseSymUse, DefSymUse, EffSymUse, OpSymUse, SigSymUse, StructFieldSymUse, TraitSymUse, TypeAliasSymUse}
import ca.uwaterloo.flix.language.ast.{Kind, SourceLocation, Symbol, Type, TypeConstructor}
import ca.uwaterloo.flix.language.fmt.*
import ca.uwaterloo.flix.language.phase.unification.SetFormula

object HoverProvider {

  def processHover(uri: String, pos: Position)(implicit root: Root, flix: Flix): Option[Hover] = {
    val consumer = StackConsumer()
    Visitor.visitRoot(root, consumer, InsideAcceptor(uri, pos))

    consumer.getStack.headOption.flatMap(hoverAny)
  }

  private def hoverAny(x: AnyRef)(implicit root: Root, flix: Flix): Option[Hover] = x match {
    // Named type references must precede the generic Type case.
    case Type.Cst(TypeConstructor.Enum(sym, _), loc) =>
      root.enums.get(sym).map(enm => hoverDecl(s"enum ${sym.toString}", FormatDoc.asMarkDown(enm.doc), loc))
    case Type.Cst(TypeConstructor.Struct(sym, _), loc) =>
      root.structs.get(sym).map(struct => hoverDecl(s"struct ${sym.toString}", FormatDoc.asMarkDown(struct.doc), loc))
    case Type.Cst(TypeConstructor.Effect(sym, _), loc) =>
      root.effects.get(sym).map(eff => hoverDecl(s"eff ${sym.toString}", FormatDoc.asMarkDown(eff.doc), loc))
        .orElse(hoverKind(TypeConstructor.Effect(sym, Kind.Eff).kind, loc))
    case Type.Alias(symUse, _, tpe, loc) => hoverTypeAlias(symUse.sym, tpe, loc)

    case tpe: Type => hoverKind(tpe.kind, tpe.loc)
    case (varSym: Symbol.VarSym, tpe: Type) => hoverType(tpe, varSym.loc)
    case exp: Expr => hoverTypeAndEff(exp.tpe, exp.eff, exp.loc)
    case Binder(sym, tpe) => hoverType(tpe, sym.loc)

    // Flix 0.76 handles uses but not the corresponding declaration names.
    case defn: Def => hoverDef(defn.sym, defn.sym.loc)
    case sig: Sig => hoverSig(sig.sym, sig.sym.loc)
    case op: Op => hoverOp(op.sym, op.sym.loc)
    case DefSymUse(sym, loc) => hoverDef(sym, loc)
    case SigSymUse(sym, loc) => hoverSig(sym, loc)
    case OpSymUse(sym, loc) => hoverOp(sym, loc)

    case enm: Enum => Some(hoverDecl(s"enum ${enm.sym.toString}", FormatDoc.asMarkDown(enm.doc), enm.sym.loc))
    case struct: Struct => Some(hoverDecl(s"struct ${struct.sym.toString}", FormatDoc.asMarkDown(struct.doc), struct.sym.loc))
    case trt: Trait => Some(hoverDecl(s"trait ${trt.sym.toString}", FormatDoc.asMarkDown(trt.doc), trt.sym.loc))
    case eff: Effect => Some(hoverDecl(s"eff ${eff.sym.toString}", FormatDoc.asMarkDown(eff.doc), eff.sym.loc))
    case alias: TypeAlias => Some(hoverDecl(
      s"type alias ${alias.sym.toString} = ${FormatType.formatType(alias.tpe)}",
      FormatDoc.asMarkDown(alias.doc),
      alias.sym.loc
    ))
    case cse: Case => Some(hoverCase(cse, cse.sym.loc))
    case field: StructField => Some(hoverType(field.tpe, field.sym.loc).get)

    case CaseSymUse(sym, loc) =>
      root.enums.get(sym.enumSym).flatMap(_.cases.get(sym)).map(cse => hoverCase(cse, loc))
    case StructFieldSymUse(sym, loc) =>
      root.structs.get(sym.structSym).flatMap(_.fields.get(sym)).flatMap(field => hoverType(field.tpe, loc))
    case TraitSymUse(sym, loc) =>
      root.traits.get(sym).map(trt => hoverDecl(s"trait ${sym.toString}", FormatDoc.asMarkDown(trt.doc), loc))
    case TypeAliasSymUse(sym, loc) =>
      root.typeAliases.get(sym).map(alias => hoverDecl(
        s"type alias ${sym.toString} = ${FormatType.formatType(alias.tpe)}",
        FormatDoc.asMarkDown(alias.doc),
        loc
      ))
    case EffSymUse(sym, qname) =>
      root.effects.get(sym).map(eff => hoverDecl(s"eff ${sym.toString}", FormatDoc.asMarkDown(eff.doc), qname.loc))

    // Datalog predicate names are a first-class part of Attune's Flix code.
    case Predicate.Head.Atom(pred, _, _, tpe, loc) => hoverPredicate(pred.name, tpe, loc)
    case Predicate.Body.Atom(pred, _, _, _, _, tpe, loc) => hoverPredicate(pred.name, tpe, loc)
    case PredicateParam(pred, tpe, loc) => hoverPredicate(pred.name, tpe, loc)

    case FormalParam(_, tpe, _, _, loc) => hoverType(tpe, loc)
    case TypeParam(_, sym, _) => hoverKind(sym.kind, sym.loc)
    case Pattern.Wild(tpe, loc) => hoverType(tpe, loc)
    case _ => None
  }

  private def hoverType(tpe: Type, loc: SourceLocation)(implicit root: Root, flix: Flix): Option[Hover] = {
    val bounds = SetFormula.formatLowerAndUpperBounds(tpe)(root)
    Some(hoverCode(s"${FormatType.formatType(tpe, minimizeEffs = true)}$bounds", loc))
  }

  private def hoverTypeAndEff(tpe: Type, eff: Type, loc: SourceLocation)(implicit flix: Flix): Option[Hover] = {
    val t = FormatType.formatType(tpe, minimizeEffs = true)
    val suffix = eff match {
      case Type.Cst(TypeConstructor.Pure, _) => ""
      case other => raw" \ " + FormatType.formatType(other, minimizeEffs = true)
    }
    Some(hoverCode(t + suffix, loc))
  }

  private def hoverDef(sym: Symbol.DefnSym, loc: SourceLocation)(implicit root: Root, flix: Flix): Option[Hover] = {
    root.defs.get(sym).map { defn =>
      hoverDecl(FormatSignature.asMarkDown(defn), FormatDoc.asMarkDown(defn.spec.doc), loc)
    }
  }

  private def hoverSig(sym: Symbol.SigSym, loc: SourceLocation)(implicit root: Root, flix: Flix): Option[Hover] = {
    root.sigs.get(sym).map { sig =>
      hoverDecl(FormatSignature.asMarkDown(sig), FormatDoc.asMarkDown(sig.spec.doc), loc)
    }
  }

  private def hoverOp(sym: Symbol.OpSym, loc: SourceLocation)(implicit root: Root, flix: Flix): Option[Hover] = {
    root.effects.get(sym.eff).flatMap(_.ops.find(_.sym == sym)).map { op =>
      hoverDecl(FormatSignature.asMarkDown(op), FormatDoc.asMarkDown(op.spec.doc), loc)
    }
  }

  private def hoverTypeAlias(sym: Symbol.TypeAliasSym, fallback: Type, loc: SourceLocation)(implicit root: Root, flix: Flix): Option[Hover] = {
    Some(root.typeAliases.get(sym) match {
      case Some(alias) => hoverDecl(
        s"type alias ${sym.toString} = ${FormatType.formatType(alias.tpe)}",
        FormatDoc.asMarkDown(alias.doc),
        loc
      )
      case None => hoverCode(FormatType.formatType(fallback), loc)
    })
  }

  private def hoverCase(cse: Case, loc: SourceLocation)(implicit flix: Flix): Hover = {
    hoverCode(s"case ${cse.sym.toString}: ${FormatScheme.formatScheme(cse.sc)}", loc)
  }

  private def hoverPredicate(name: String, tpe: Type, loc: SourceLocation)(implicit flix: Flix): Option[Hover] = {
    Some(hoverCode(s"$name: ${FormatType.formatType(tpe)}", loc))
  }

  private def hoverKind(kind: Kind, loc: SourceLocation): Option[Hover] = {
    Some(hoverCode(FormatKind.formatKind(kind), loc))
  }

  private def hoverCode(code: String, loc: SourceLocation): Hover = {
    val contents = MarkupContent(MarkupKind.Markdown, s"```flix\n$code\n```\n")
    Hover(contents, Range.from(loc))
  }

  private def hoverDecl(code: String, doc: String, loc: SourceLocation): Hover = {
    val documentation = if (doc.isEmpty) "" else s"\n$doc\n"
    val contents = MarkupContent(MarkupKind.Markdown, s"```flix\n$code\n```\n$documentation")
    Hover(contents, Range.from(loc))
  }
}
