(***********************************************************************)
(*                                                                     *)
(*                                OCaml                                *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the Q Public License version 1.0.               *)
(*                                                                     *)
(***********************************************************************)

(* Abstract syntax tree produced by parsing *)

open Asttypes

(* Extension points *)

type attribute = string * expression
      (* [@id E]
         [@id]     (expr = ())

         [@@id EXPR]
         [@@id]    (expr = ())
       *)

and extension = string * expression
      (* [%id E]
         [%id]     (expr = ())

         [%%id EXPR]
         [%%id]    (expr = ())
       *)

and attributes = attribute list

(* Type expressions for the core language *)

and core_type =
    {
     ptyp_desc: core_type_desc;
     ptyp_loc: Location.t;
     ptyp_attributes: attributes; (* T [@id1 E1] [@id2 E2] ... *)
    }

and core_type_desc =
  | Ptyp_any
        (*  _ *)
  | Ptyp_var of string
        (* 'a *)
  | Ptyp_arrow of label * core_type * core_type
        (* T1 -> T2       (label = "")
           ~l:T1 -> T2    (label = "l")
           ?l:T1 -> T2    (label = "?l")
         *)
  | Ptyp_tuple of core_type list
        (* T1 * ... * Tn   (n >= 2) *)
  | Ptyp_constr of Longident.t loc * core_type list
        (* tconstr
           T tconstr
           (T1, ..., Tn) tconstr
         *)
  | Ptyp_object of (string * core_type) list * closed_flag
        (* < l1:T1; ...; ln:Tn >     (flag = Closed)
           < l1:T1; ...; ln:Tn; .. > (flag = Open)
         *)
  | Ptyp_class of Longident.t loc * core_type list * label list
        (* #tconstr
           T #tconstr
           (T1, ..., Tn) tconstr

           The label list is used for the deprecated syntax:
           #tconstr [> `A1 ... `An]
         *)
  | Ptyp_alias of core_type * string
        (* T as 'a *)
  | Ptyp_variant of row_field list * closed_flag * label list option
        (* [ `A|`B ]         (flag = Closed; labels = None)
           [> `A|`B ]        (flag = Open;   labels = None)
           [< `A|`B ]        (flag = Closed; labels = Some [])
           [< `A|`B > `X `Y ](flag = Closed; labels = Some ["X";"Y"])
         *)
  | Ptyp_poly of string list * core_type
        (* 'a1 ... 'an. T *)
  | Ptyp_package of package_type
        (* (module S) *)
  | Ptyp_extension of extension
        (* [%id E] *)

and package_type = Longident.t loc * (Longident.t loc * core_type) list
      (*
        (module S)
        (module S with type t1 = T1 and ... and tn = Tn)
       *)

and row_field =
  | Rtag of label * bool * core_type list
        (* [`A]                   ( true,  [] )
           [`A of T]              ( false, [T] )
           [`A of T1 & .. & Tn]   ( false, [T1;...Tn] )
           [`A of & T1 & .. & Tn] ( true,  [T1;...Tn] )
         *)
  | Rinherit of core_type
        (* [ T ] *)

(* Type expressions for the class language *)

and 'a class_infos =
  { pci_virt: virtual_flag;
    pci_params: (string loc * variance) list * Location.t;
    pci_name: string loc;
    pci_expr: 'a;
    pci_loc: Location.t;
    pci_attributes: attributes;
   }

(* Value expressions for the core language *)

and pattern =
  {
   ppat_desc: pattern_desc;
   ppat_loc: Location.t;
   ppat_attributes: attributes; (* P [@id1 E1] [@id2 E2] ... *)
  }

and pattern_desc =
  | Ppat_any
        (* _ *)
  | Ppat_var of string loc
        (* x *)
  | Ppat_alias of pattern * string loc
        (* P as 'a *)
  | Ppat_constant of constant
        (* 1, 'a', "true", 1.0, 1l, 1L, 1n *)
  | Ppat_tuple of pattern list
        (* (P1, ..., Pn)   (n >= 2) *)
  | Ppat_construct of Longident.t loc * pattern option * bool
        (* C                (None, false)
           C P              (Some P, false)

           Constructors with multiple arguments are represented
           by storing a Ppat_tuple in P.

           bool = true is never created by the standard parser.
           It can be used when P is a Ppat_tuple to inform the
           type-checker that the length of that tuple corresponds
           to the number of parameters for that constructor (otherwise
           this is inferred from the definition of the constructor).
           This can be useful with a different concrete syntax
           which distinguishes n-ary constructors from constructors
           with a tuple argument in patterns.
         *)

  | Ppat_variant of label * pattern option
        (* `A             (None)
           `A of P        (Some P)
         *)
  | Ppat_record of (Longident.t loc * pattern) list * closed_flag
        (* { l1=P1; ...; ln=Pn }     (flag = Closed)
           { l1=P1; ...; ln=Pn; _}   (flag = Open)
         *)
  | Ppat_array of pattern list
        (* [| P1; ...; Pn |] *)
  | Ppat_or of pattern * pattern
        (* P1 | P2 *)
  | Ppat_constraint of pattern * core_type
        (* (P : T) *)
  | Ppat_type of Longident.t loc
        (* #tconst *)
  | Ppat_lazy of pattern
        (* lazy P *)
  | Ppat_unpack of string loc
        (* (module P)
           Note: (module P : S) is represented as Ppat_constraint(Ppat_unpack, Ptyp_package)
         *)
  | Ppat_extension of extension
        (* [%id E] *)

and expression =
    {
     pexp_desc: expression_desc;
     pexp_loc: Location.t;
     pexp_attributes: attributes; (* E [@id1 E1] [@id2 E2] ... *)
    }

and expression_desc =
  | Pexp_ident of Longident.t loc
        (* x
           M.x
         *)
  | Pexp_constant of constant
        (* 1, 'a', "true", 1.0, 1l, 1L, 1n *)
  | Pexp_let of rec_flag * (pattern * expression) list * expression
        (* let P1 = E1 and ... and Pn = EN in E       (flag = Nonrecursive)
           let rec P1 = E1 and ... and Pn = EN in E   (flag = Recursive)
         *)
  | Pexp_function of label * expression option *
        (pattern * guarded_expression) list
        (* function P1 -> E1 | ... | Pn -> En    (lab = "", None)
           fun P1 -> E1                          (lab = "", None)
           fun ~l:P1 -> E1                       (lab = "l", None)
           fun ?l:P -> E1                        (lab = "?l", None)
           fun ?l:(P1 = E0) -> E1                (lab = "?l", Some E0)

           Notes:
           - n >= 1
           - There is no concrete syntax if n >= 2 and lab <> ""
           - If E0 is provided, lab must start with '?'
         *)
  | Pexp_apply of expression * (label * expression) list
        (* E0 ~l1:E1 ... ~ln:En
           li can be empty (non labeled argument) or start with '?'
           (optional argument).
         *)
  | Pexp_match of expression * (pattern * guarded_expression) list
        (* match E0 with P1 -> E1 | ... | Pn -> En *)
  | Pexp_try of expression * (pattern * guarded_expression) list
        (* try E0 with P1 -> E1 | ... | Pn -> En *)
  | Pexp_tuple of expression list
        (* (E1, ..., En)   (n >= 2) *)
  | Pexp_construct of Longident.t loc * expression option * bool
        (* C                (None, false)
           C E              (Some E, false)

           Constructors with multiple arguments are represented
           by storing a Pexp_tuple in E.
        *)
  | Pexp_variant of label * expression option
        (* `A             (None)
           `A of E        (Some E)
         *)
  | Pexp_record of (Longident.t loc * expression) list * expression option
        (* { l1=P1; ...; ln=Pn }     (None)
           { E0 with l1=P1; ...; ln=Pn }   (Some E0)
         *)
  | Pexp_field of expression * Longident.t loc
        (* E.l *)
  | Pexp_setfield of expression * Longident.t loc * expression
        (* E1.l <- E2 *)
  | Pexp_array of expression list
        (* [| E1; ...; En |] *)
  | Pexp_ifthenelse of expression * expression * expression option
        (* if E1 then E2 else E3 *)
  | Pexp_sequence of expression * expression
        (* E1; E2 *)
  | Pexp_while of expression * expression
        (* while E1 do E2 done *)
  | Pexp_for of
      string loc *  expression * expression * direction_flag * expression
        (* for i = E1 to E2 do E3 done      (flag = Upto)
           for i = E1 downto E2 do E3 done  (flag = Downto)
         *)
  | Pexp_constraint of expression * core_type option * core_type option
        (* (E : T1)         (Some T1, None)
           (E :> T2)        (None, Some T2)
           (E : T1 :> T2)   (Some T1, Some T2)

           Invariant: one of the two types must be provided
           (otherwise this is currently accepted as equivalent to just E).
         *)
  | Pexp_when of expression * expression
        (* ... when E1 -> E2
           This node can occur only in contexts marked as guarded_expression.
         *)
  | Pexp_send of expression * string
        (*  E # m *)
  | Pexp_new of Longident.t loc
        (* new M.c *)
  | Pexp_setinstvar of string loc * expression
        (* x <- 2 *)
  | Pexp_override of (string loc * expression) list
        (* {< x1 = E1; ...; Xn = En >} *)
  | Pexp_letmodule of string loc * module_expr * expression
        (* let module M = ME in E *)
  | Pexp_assert of expression
        (* assert E
           Note: "assert false" is represented in a specific way
           (see below).
         *)
  | Pexp_assertfalse
        (* assert false *)
  | Pexp_lazy of expression
        (* lazy E *)
  | Pexp_poly of expression * core_type option
        (* Used for method bodies.
           TODO: this must probably be cleaned up. *)
  | Pexp_object of class_structure
        (* object ... end *)
  | Pexp_newtype of string * expression
        (* fun (type t) -> E *)
  | Pexp_pack of module_expr
        (* (module ME)

           (module ME : S) is represented as
           Pexp_constraint(Pexp_pack, Some (Ptyp_package S), None) *)
  | Pexp_open of Longident.t loc * expression
        (* let open M in E *)
  | Pexp_extension of extension
        (* [%id E] *)

and guarded_expression = expression
   (* This type abbreviation is used to mark contexts where Pexp_when
      can be used. *)

(* Value descriptions *)

and value_description =
  { pval_name: string loc;
    pval_type: core_type;
    pval_prim: string list;
    pval_attributes: attributes;
    pval_loc: Location.t
    }

(* Type declarations *)

and type_declaration =
  { ptype_name: string loc;
    ptype_params: (string loc option * variance) list;
    ptype_cstrs: (core_type * core_type * Location.t) list;
    ptype_kind: type_kind;
    ptype_private: private_flag;
    ptype_manifest: core_type option;
    ptype_attributes: attributes;
    ptype_loc: Location.t }

and type_kind =
    Ptype_abstract
  | Ptype_variant of constructor_declaration list
  | Ptype_record of label_declaration list

and label_declaration =
    {
     pld_name: string loc;
     pld_mutable: mutable_flag;
     pld_type: core_type;
     pld_loc: Location.t;
     pld_attributes: attributes;
    }

and constructor_declaration =
    {
     pcd_name: string loc;
     pcd_args: core_type list;
     pcd_res: core_type option;
     pcd_loc: Location.t;
     pcd_attributes: attributes;
    }

(* Type expressions for the class language *)

and class_type =
    {
     pcty_desc: class_type_desc;
     pcty_loc: Location.t;
     pcty_attributes: attributes;
    }

and class_type_desc =
    Pcty_constr of Longident.t loc * core_type list
  | Pcty_signature of class_signature
  | Pcty_fun of label * core_type * class_type
  | Pcty_extension of extension

and class_signature = {
    pcsig_self: core_type;
    pcsig_fields: class_type_field list;
    pcsig_loc: Location.t;
  }

and class_type_field = {
    pctf_desc: class_type_field_desc;
    pctf_loc: Location.t;
    pctf_attributes: attributes;
  }

and class_type_field_desc =
    Pctf_inherit of class_type
  | Pctf_val of (string * mutable_flag * virtual_flag * core_type)
  | Pctf_method  of (string * private_flag * virtual_flag * core_type)
  | Pctf_constraint  of (core_type * core_type)
  | Pctf_extension of extension

and class_description = class_type class_infos

and class_type_declaration = class_type class_infos

(* Value expressions for the class language *)

and class_expr =
  {
   pcl_desc: class_expr_desc;
   pcl_loc: Location.t;
   pcl_attributes: attributes;
  }

and class_expr_desc =
    Pcl_constr of Longident.t loc * core_type list
  | Pcl_structure of class_structure
  | Pcl_fun of label * expression option * pattern * class_expr
  | Pcl_apply of class_expr * (label * expression) list
  | Pcl_let of rec_flag * (pattern * expression) list * class_expr
  | Pcl_constraint of class_expr * class_type
  | Pcl_extension of extension

and class_structure = {
    pcstr_self: pattern;
    pcstr_fields: class_field list;
  }

and class_field = {
    pcf_desc: class_field_desc;
    pcf_loc: Location.t;
    pcf_attributes: attributes;
  }

and class_field_desc =
    Pcf_inherit of override_flag * class_expr * string option
  | Pcf_val of (string loc * mutable_flag * class_field_kind)
  | Pcf_method of (string loc * private_flag * class_field_kind)
  | Pcf_constraint of (core_type * core_type)
  | Pcf_initializer of expression
  | Pcf_extension of extension

and class_field_kind =
  | Cfk_virtual of core_type
  | Cfk_concrete of override_flag * expression

and class_declaration = class_expr class_infos

(* Type expressions for the module language *)

and module_type =
  { pmty_desc: module_type_desc;
    pmty_loc: Location.t;
    pmty_attributes: attributes;
   }

and module_type_desc =
    Pmty_ident of Longident.t loc
  | Pmty_signature of signature
  | Pmty_functor of string loc * module_type * module_type
  | Pmty_with of module_type * (Longident.t loc * with_constraint) list
  | Pmty_typeof of module_expr
  | Pmty_extension of extension

and signature = signature_item list

and signature_item =
  { psig_desc: signature_item_desc;
    psig_loc: Location.t }

and signature_item_desc =
    Psig_value of value_description
  | Psig_type of type_declaration list
  | Psig_exception of constructor_declaration
  | Psig_module of module_declaration
  | Psig_recmodule of module_declaration list
  | Psig_modtype of module_type_declaration
  | Psig_open of Longident.t loc * attributes
  | Psig_include of module_type * attributes
  | Psig_class of class_description list
  | Psig_class_type of class_type_declaration list
  | Psig_attribute of attribute
  | Psig_extension of extension * attributes

and module_declaration =
    {
     pmd_name: string loc;
     pmd_type: module_type;
     pmd_attributes: attributes;
    }

and module_type_declaration =
    {
     pmtd_name: string loc;
     pmtd_type: module_type option;
     pmtd_attributes: attributes;
    }

and with_constraint =
    Pwith_type of type_declaration
  | Pwith_module of Longident.t loc
  | Pwith_typesubst of type_declaration
  | Pwith_modsubst of Longident.t loc

(* Value expressions for the module language *)

and module_expr =
  { pmod_desc: module_expr_desc;
    pmod_loc: Location.t;
    pmod_attributes: attributes;
 }

and module_expr_desc =
    Pmod_ident of Longident.t loc
  | Pmod_structure of structure
  | Pmod_functor of string loc * module_type * module_expr
  | Pmod_apply of module_expr * module_expr
  | Pmod_constraint of module_expr * module_type
  | Pmod_unpack of expression
  | Pmod_extension of extension

and structure = structure_item list

and structure_item =
  { pstr_desc: structure_item_desc;
    pstr_loc: Location.t }

and structure_item_desc =
    Pstr_eval of expression * attributes
  | Pstr_value of rec_flag * (pattern * expression) list * attributes
  | Pstr_primitive of value_description
  | Pstr_type of type_declaration list
  | Pstr_exception of constructor_declaration
  | Pstr_exn_rebind of string loc * Longident.t loc * attributes
  | Pstr_module of module_binding
  | Pstr_recmodule of module_binding list
  | Pstr_modtype of module_type_binding
  | Pstr_open of Longident.t loc * attributes
  | Pstr_class of class_declaration list
  | Pstr_class_type of class_type_declaration list
  | Pstr_include of module_expr * attributes
  | Pstr_attribute of attribute
  | Pstr_extension of extension * attributes

and module_binding =
    {
     pmb_name: string loc;
     pmb_expr: module_expr;
     pmb_attributes: attributes;
    }

and module_type_binding =
    {
     pmtb_name: string loc;
     pmtb_type: module_type;
     pmtb_attributes: attributes;
    }

(* Toplevel phrases *)

type toplevel_phrase =
    Ptop_def of structure
  | Ptop_dir of string * directive_argument

and directive_argument =
    Pdir_none
  | Pdir_string of string
  | Pdir_int of int
  | Pdir_ident of Longident.t
  | Pdir_bool of bool
