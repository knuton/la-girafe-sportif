Require Import Untyped.
Require Import Subst.
Require Import Beta.
Require Import Relation_Operators.
Require Import Coq.Program.Equality.
Require Import Coq.Logic.Classical_Prop.

(** Reduction Numbering (Definition 2.1) **)

(* Predicate characterising abstractions. *)

Inductive abstr : lterm -> Prop :=
  | islam : forall M, abstr (Lam M).

Example notabstr : ~ abstr (`"x").
Proof. unfold not. intro. inversion H. Qed.

(* Count the total number of redexes in a term. *)

Fixpoint redcount (M : lterm) : nat :=
  match M with
  | Var i as v => 0
  | App (Lam N) N' => (redcount N) + (redcount N') + 1
  | App N N' => (redcount N) + (redcount N')
  | Lam N => redcount N
  end.

Example countright :
  redcount (`"x") = 0 /\ redcount (`"x" $ `"z") = 0 /\ redcount ((\"x" ~> (\"y" ~> `"y" $ `"y") $ `"x") $ `"z") = 2. 
Proof.
  split.
    compute. reflexivity.
    split; compute; reflexivity.
Qed.

(* This is the predicate defined in 2.1.
   [nthred n t t'] states that [t'] is the result of reducing the [n]-th redex in [t].
*)

Inductive nthred : nat -> lterm -> lterm -> Prop :=
  | nthred_prim : forall A B,
      nthred 1 (App (Lam A) B) (subst 0 B A)
  | nthred_concr : forall n A B C,
      ~ abstr A -> nthred n A B -> nthred n (App A C) (App B C)
  | nthred_concrplus : forall n A B C,
      abstr A -> nthred n A B -> nthred (n+1) (App A C) (App B C)
  | nthred_concl : forall n A B C,
      ~ abstr C -> nthred n A B -> nthred (n + redcount C) (App C A) (App C B)
  | nthred_conclplus : forall n A B C,
      abstr C -> nthred n A B -> nthred (n + (redcount C) + 1) (App C A) (App C B)
  | nthred_abst : forall n A B,
      nthred n A B -> nthred n (Lam A) (Lam B).

Example prim : nthred 1 ((\"x" ~> `"x") $ `"y") (`"y").
Proof. apply nthred_prim. Qed.

Example concr : nthred 1 ((\"x" ~> `"x") $ `"y" $ `"z") (`"y" $ `"z").
Proof.
  apply nthred_concr.
  unfold not. intro. inversion H.
  apply nthred_prim.
Qed.

Example concrplus :
  nthred 2 ((\"y" ~> (\"x" ~> `"x") $ `"y") $ `"z") ((\"y" ~> `"y") $ `"z").
Proof.
  assert (M: 2 = 1 + 1). reflexivity. rewrite M.
  apply nthred_concrplus.
    apply islam.
    apply nthred_abst. apply nthred_prim.
Qed.

Example concl :
  nthred 2 (((\"x" ~> `"x") $ `"z") $ ((\"x" ~> `"x") $ `"z")) (((\"x" ~> `"x") $ `"z") $ `"z").
Proof.
  assert (M: 2 = 1 + redcount ((\"x" ~> `"x") $ `"z")). simpl. reflexivity. rewrite M.
  apply nthred_concl.
  unfold not. intro. inversion H.
  apply nthred_prim.
Qed.

Example conclplus :
  nthred 3 ((\"y" ~> ((\"x" ~> `"x") $ `"z")) $ ((\"x" ~> `"x") $ `"z")) ((\"y" ~> ((\"x" ~> `"x") $ `"z")) $ `"z").
Proof.
  assert (M: 3 = 1 + redcount (\"y" ~> (\"x" ~> `"x") $ `"z") + 1). simpl. reflexivity. rewrite M.
  apply nthred_conclplus.
  apply islam.
  apply nthred_prim.
Qed.

(** Beta-reduction and left-most reduction (Definition 2.2) **)

(* The paper defines beta-reduction in terms of the [nthred] relation.
   Equivalence with the definition found in [Beta] has yet to be proven (if necessary).
*)

Definition bet (A B : lterm) : Prop := exists n : nat, nthred n A B.

Definition betstar := clos_refl_trans lterm bet.
Definition betstar_step := rt_step lterm bet.
Definition betstar_refl := rt_refl lterm bet.
Definition betstar_trans := rt_trans lterm bet.

(* Left-most reduction is simply reduction of the first redex. *)

Definition lmost (A B : lterm) : Prop := nthred 1 A B.

Definition lstar := clos_refl_trans lterm lmost.
Definition lstar_step := rt_step lterm lmost.
Definition lstar_refl := rt_refl lterm lmost.
Definition lstar_trans := rt_trans lterm lmost.

(** Head-reduction in application (Definition 3.1) **)

Inductive hap' : lterm -> lterm -> Prop :=
  | hap'_hred : forall A B, hap' (App (Lam A) B) (subst 0 B A)
  | hap'_hreds : forall A B C, hap' A B -> hap' (App A C) (App B C).

Inductive hap : lterm -> lterm -> Prop :=
  | hap_refl : forall A, hap A A
  | hap_hred : forall A B, hap' A B -> hap A B
  | hap_trans : forall A B C, hap A B -> hap B C -> hap A C.

(** Standard reduction (Definition 3.2) **)

Inductive st : lterm -> lterm -> Prop :=
  | st_hap : forall L x, hap L (Var x) -> st L (Var x)
  | st_hap_st_st : forall L A B C D,
      hap L (App A B) -> st A C -> st B D -> st L (App C D)
  | st_haplam_st : forall L A B,
      hap L (Lam A) -> st A B -> st L (Lam B).

(** Lemma 3.3 **)

(* (1) *)
Lemma hap_lstar : forall M N, hap M N -> lstar M N.
Proof.
  intros. induction H as [ t | t0 t1 | t1 t2 t3].
    (* hap_refl *)
    apply lstar_refl.
    (* hap_hred *)
    apply lstar_step. unfold lmost. induction H.
      apply nthred_prim.
      apply nthred_concr. unfold not. intro. induction H. inversion H0. inversion H0. assumption.
    (* hap_trans *)
    apply lstar_trans with (y := t2). apply IHhap1. apply IHhap2.
Qed.

(* (2) needs definition not yet introduced *)

(** Lemma 3.4 **)

(* (1) *)
Lemma st_refl : forall M, st M M.
Proof.
  intros M.
  induction M.
    apply st_hap. apply hap_refl.
    apply st_haplam_st with (A := M). apply hap_refl. assumption.
    apply st_hap_st_st with (A := M1) (B := M2). apply hap_refl. assumption. assumption.
Qed.

(* (2) *)
Lemma hap__app_hap : forall M N P,
  hap M N -> hap (App M P) (App N P).
Proof.
  intros. induction H.
    apply hap_refl.
    apply hap_hred. apply hap'_hreds. assumption.
    apply hap_trans with (B := App B P); assumption.
Qed.

(* (3) *)
Lemma hap_st__st : forall L M N,
  hap L M -> st M N -> st L N.
Proof.
  intros. induction H0.
    apply st_hap. apply hap_trans with (B := L0). assumption. assumption.
    apply st_hap_st_st with (A := A) (B := B).
      apply hap_trans with (B := L0); assumption.
      assumption. assumption.
    apply st_haplam_st with (A := A).
      apply hap_trans with (B := L0); assumption.
      assumption.
Qed.

(* (4) *)

(* We first prove [subst_hap'], after which the actual lemma is easy to show. *)

Lemma subst_hap' : forall M N P, forall n,
  hap' M N -> hap' (subst n P M) (subst n P N).
Proof.
  intros. induction H.
    (* hap'_hred *)
    simpl.
    assert (EXP: subst n P (subst 0 B A) = subst 0 (subst n P B) (subst (n+1) P A)).
      simpl. assert (T1: subst n P B = subst (n - 0) P B).
        assert (T2: n = n - 0). omega. rewrite <- T2. reflexivity.
      rewrite T1. apply subst_lemma. omega.
    rewrite EXP. apply hap'_hred.
    (* hap'_hreds *)
    apply hap'_hreds. apply IHhap'.
Qed.

Lemma hap__hap_subst : forall M N P,
  hap M N -> forall n : nat, hap (subst n P M) (subst n P N).
Proof.
  intros M N P H n. induction H.
    apply hap_refl.
    apply hap_hred. apply subst_hap'. assumption.
    apply hap_trans with (B := subst n P B); assumption.
Qed.

(* We need to do quite a bit of busywork for (5). *)

(* First, lift-independence of [hap], which is easy. *)

Lemma lift_hap' : forall M N,
  hap' M N -> forall n k, hap' (lift n k M) (lift n k N).
Proof.
  intros M N H. induction H.
    (* hap'_hred *)
    intros n k. simpl.
    rewrite lift_distr_subst.
    replace (k - 0) with k by omega.
    apply hap'_hred. omega.
    (* hap'_hreds *)
    intros n k. rewrite lift_app. rewrite lift_app. apply hap'_hreds. apply (IHhap' n).
Qed.

Lemma lift_hap : forall M N,
  hap M N -> forall n k, hap (lift n k M) (lift n k N).
Proof.
  intros. induction H.
    (* hap_refl *)
    apply hap_refl.
    (* hap_hreds *)
    apply hap_hred. apply lift_hap'. assumption.
    (* hap_trans *)
    apply hap_trans with (B := lift n k B); assumption.
Qed.

(* Second, lift-independence for [st], which is more intricate. *)

Lemma hap'_no_lhs_var : forall i M,
  ~ hap' (Var i) M.
Proof. intros. unfold not. intro H. inversion H. Qed.

Lemma hap_lefthandside_var : forall i M,
  hap (Var i) M -> M = Var i.
Proof.
  intros. dependent induction H.
    reflexivity.
    contradict H. apply hap'_no_lhs_var.
    apply IHhap2. assumption.
Qed.

Example lift_first_hap_ex1 : hap (lift 4 6 (App (Lam (Var 0)) (Var 3))) (Var 3).
Proof. simpl. apply hap_hred. apply hap'_hred. Qed.

Example lift_first_hap_ex2 :
  hap
    (lift 4 4 ((App (App (Lam (Var 0)) (Lam (Var 4))) (Var 7))))
    (Var 3).
Proof.
  simpl.
  apply hap_trans with (B := App (Lam (Var 4)) (Var 11)).
  apply hap_hred.
    apply hap'_hreds. apply hap'_hred.
    assert (Var 3 = subst 0 (Var 11) (Var 4)). reflexivity. rewrite H.
    apply hap_hred. apply hap'_hred.
Qed.

Lemma subst_to_var : forall M N i,
  subst 0 N M = Var i -> M = Var 0 /\ N = Var i \/ M = Var (i + 1).
Proof.
  intros. induction M.
    (* Var *)
    inversion H. case_eq (Compare_dec.nat_compare n 0).
      (* Eq *)
      intros nEQ0. rewrite nEQ0 in H1. rewrite Compare_dec.nat_compare_eq_iff in nEQ0.
      left. split.
        f_equal. assumption.
        rewrite (lift_0_ident N 0). reflexivity.
      (* Lt *)
      intro nLT0. rewrite <- Compare_dec.nat_compare_lt in nLT0. contradict nLT0. omega.
      (* Gt *)
      intro nGT0. rewrite nGT0 in H1. rewrite <- Compare_dec.nat_compare_gt in nGT0.
      right. f_equal. rewrite Plus.plus_comm.
      inversion H1. apply Minus.le_plus_minus. omega.
    (* Lam *)
    simpl in H. inversion H.
    (* App *)
    simpl in H. inversion H.
Qed.

Lemma subst_indist : forall i M N,
  i > 0 -> subst 0 M (Var i) = subst 0 N (Var i).
Proof.
  intros. simpl. rewrite Compare_dec.nat_compare_gt in H. rewrite H. reflexivity.
Qed.

(* We need to establish that abstractions can appear on the left side of hap
   only due to the reflexive rule.
*)

Lemma not_hap'_lam_var : forall M i, ~ hap' (Lam M) i.
Proof. unfold not. intros. dependent induction H. Qed.

Lemma not_hap_lam : forall M N, N <> Lam M -> ~ hap (Lam M) N.
Proof.
  unfold not. intros.
  dependent induction H0.
    assert (ID: Lam M = Lam M) by reflexivity. apply H in ID. assumption.
    contradict H0. apply not_hap'_lam_var.
    apply IHhap2 in H. assumption. apply NNPP in IHhap1. assumption.
Qed.

Lemma lift_first_hap : forall M n i k,
  hap M (Var i) -> i < k -> hap (lift n k M) (Var i).
Proof.
  intros M n i k H iLTk.
  assert (Var i = lift n k (Var i)). simpl. case_eq (Compare_dec.lt_dec i k).
    (* i < k *)
    intros. reflexivity.
    (* ~ i < k *)
    intros. contradict iLTk. assumption.
  rewrite H0. apply lift_hap. assumption.
Qed.

Lemma lift_st : forall M N,
  st M N -> forall n k, st (lift n k M) (lift n k N).
Proof.
  intros M N H. dependent induction H.
    (* st_hap *)
    intros n k. simpl. case_eq (Compare_dec.lt_dec x k).
      (* i < k *)
      intros. apply st_hap. apply lift_first_hap; assumption.
      (* ~ i < k *)
      intros. apply st_hap.
      assert (FLD: Var (x + n) = lift n k (Var x)). simpl.
        case_eq (Compare_dec.lt_dec x k). intros. contradiction. intros. reflexivity.
      rewrite FLD. apply lift_hap. assumption.
    (* st_hap_st_st *)
    intros n k. apply st_hap_st_st with (A := lift n k A) (B := lift n k B).
    rewrite <- lift_app. apply lift_hap. assumption.
    fold lift. apply IHst1.
    fold lift. apply IHst2.
    (* st_haplam_st *)
    intros n k. apply st_haplam_st with (A := lift n (k+1) A).
    rewrite <- lift_lam. apply lift_hap. assumption.
    fold lift. apply IHst.
Qed.

(* (5) *)
Lemma st_st__st_subst : forall M N P Q,
  st M N -> st P Q -> forall n, st (subst n P M) (subst n Q N).
Proof.
  intros M N P Q HMN HPQ. induction HMN.
    (* hap with Var *)
    intro n.
    assert (hap (subst n P L) (subst n P L)). apply hap_refl.
    assert (hap (subst n P L) (subst n P (Var x))). apply hap__hap_subst. assumption.
    apply hap_st__st with (M := subst n P (Var x)). assumption.
    simpl. case_eq (Compare_dec.nat_compare x n).
      (* Eq *)
      intro. apply lift_st. assumption.
      (* Lt *)
      intro. apply st_hap. apply hap_refl.
      (* Gt *)
      intro. apply st_hap. apply hap_refl.
    (* hap with App *)
    intro n. rewrite subst_app.
    apply st_hap_st_st with (A := subst n P A) (B := subst n P B).
    rewrite <- subst_app.
    apply hap__hap_subst.
    assumption. apply (IHHMN1 n). apply (IHHMN2 n).
    (* hap with Lam *)
    intro n.
    apply st_haplam_st with (A := subst (n+1) P A).
    rewrite <- subst_lam.
    apply hap__hap_subst.
    assumption.
    apply (IHHMN (n+1)).
Qed.

(* Lemma 3.5 *)

Lemma st_app__st_subst : forall L M N,
  st L (App (Lam M) N) -> st L (subst 0 N M).
Proof.
  intros. inversion H as [ | X P N' |]. inversion H4 as [ | | X' M' ].
  apply hap_st__st with (M := subst 0 N' M').
  apply hap_trans with (B := App (Lam M') N').
  apply hap_trans with (B := App P N').
    assumption.
    apply hap__app_hap. apply H7.
    apply hap_hred. apply hap'_hred.
  apply st_st__st_subst; assumption.
Qed.

(* Lemma 3.6 *)

Lemma st_nthred__st : forall M N i,
  nthred i M N -> forall L, st L M -> st L N.
Proof.
  intros M N i Hbet.
  induction Hbet as [A B | n A B C | n A B C | n A B C | n A B C | n A B].
    (* 2.1 (1) *)
    intros L Hst.
    apply st_app__st_subst. assumption.
    (* 2.1 (2) *)
    intros L Hst.
    inversion Hst as [| X A' C' |].
    apply st_hap_st_st with (A := A') (B := C').
      assumption.
      apply IHHbet. assumption.
      assumption.
    (* 2.1 (3) *)
    intros L Hst.
    inversion Hst as [| X A' C' |].
    apply st_hap_st_st with (A := A') (B := C').
      assumption.
      apply (IHHbet A'); assumption.
      assumption.
    (* 2.1 (4) *)
    intros L Hst.
    inversion Hst as [| X A' C' |].
    apply st_hap_st_st with (A := A') (B := C').
      assumption.
      assumption.
      apply (IHHbet C'); assumption.
    (* 2.1 (5) *)
    intros L Hst.
    inversion Hst as [| X A' C' |].
    apply st_hap_st_st with (A := A') (B := C').
      assumption.
      assumption.
      apply (IHHbet C'); assumption.
    (* 2.1 (6) *)
    intros L Hst.
    inversion Hst as [| | X A'].
    apply st_haplam_st with (A := A').
      assumption.
      apply (IHHbet A'). assumption.
Qed.

Lemma st_bred__st : forall L M N,
  bet M N -> st L M -> st L N.
Proof.
  intros. unfold bet in H. inversion H.
  apply st_nthred__st with (M := M) (i := x); assumption.
Qed.

(* Lemma 3.7 *)

Lemma betstar_st : forall M N,
  betstar M N -> st M N.
Proof.
  intros M N Hstar. induction Hstar.
    (* step *)
    intros.
    apply (st_bred__st x x y). assumption. apply st_refl.
    (* refl *)
    apply st_refl.
    (* trans *)
    apply (Operators_Properties.clos_refl_trans_ind_left lterm bet y).
      assumption.
      intros. apply (st_bred__st x y0 z0); assumption.
      assumption.
Qed.