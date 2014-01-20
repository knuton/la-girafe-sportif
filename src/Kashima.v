Require Import Untyped.
Require Import Subst.
Require Import Beta.
Require Import Relation_Operators.
Require Import Coq.Program.Equality.

(** Reduction Numbering (Definition 2.1) **)

(* Predicate characterising abstractions. *)

Inductive abstr : lterm -> Prop :=
  | islam : forall t, abstr (Lam t).

Example notabstr : ~ abstr (`"x").
Proof. unfold not. intro. inversion H. Qed.

(* Count the total number of redexes in a term. *)

Fixpoint redcount (t : lterm) : nat :=
  match t with
  | Var i as v => 0
  | App (Lam tinner) targ => (redcount tinner) + (redcount targ) + 1
  | App t1 t2 => (redcount t1) + (redcount t2)
  | Lam t => redcount t
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
  | nthred_prim : forall t1 t2,
      nthred 1 (App (Lam t1) t2) (subst 0 t2 t1)
  | nthred_concr : forall n t1 t2 t3,
      ~ abstr t1 /\ nthred n t1 t2 -> nthred n (App t1 t3) (App t2 t3)
  | nthred_concrplus : forall n t1 t2 t3,
      abstr t1 /\ nthred n t1 t2 -> nthred (n+1) (App t1 t3) (App t2 t3)
  | nthred_concl : forall n t1 t2 t3,
      ~ abstr t3 /\ nthred n t1 t2 -> nthred (n + redcount t3) (App t3 t1) (App t3 t2)
  | nthred_conclplus : forall n t1 t2 t3,
      abstr t3 /\ nthred n t1 t2 -> nthred (n + (redcount t3) + 1) (App t3 t1) (App t3 t2)
  | nthred_abst : forall n t1 t2,
      nthred n t1 t2 -> nthred n (Lam t1) (Lam t2).

Example prim : nthred 1 ((\"x" ~> `"x") $ `"y") (`"y").
Proof. apply nthred_prim. Qed.

Example concr : nthred 1 ((\"x" ~> `"x") $ `"y" $ `"z") (`"y" $ `"z").
Proof.
  apply nthred_concr.
  split.
    unfold not. intro. inversion H.
    apply nthred_prim.
Qed.

Example concrplus :
  nthred 2 ((\"y" ~> (\"x" ~> `"x") $ `"y") $ `"z") ((\"y" ~> `"y") $ `"z").
Proof.
  assert (M: 2 = 1 + 1). reflexivity. rewrite M.
  apply nthred_concrplus. split.
    apply islam.
    apply nthred_abst. apply nthred_prim.
Qed.

Example concl :
  nthred 2 (((\"x" ~> `"x") $ `"z") $ ((\"x" ~> `"x") $ `"z")) (((\"x" ~> `"x") $ `"z") $ `"z").
Proof.
  assert (M: 2 = 1 + redcount ((\"x" ~> `"x") $ `"z")). simpl. reflexivity. rewrite M.
  apply nthred_concl. split.
    unfold not. intro. inversion H.
    apply nthred_prim.
Qed.

Example conclplus :
  nthred 3 ((\"y" ~> ((\"x" ~> `"x") $ `"z")) $ ((\"x" ~> `"x") $ `"z")) ((\"y" ~> ((\"x" ~> `"x") $ `"z")) $ `"z").
Proof.
  assert (M: 3 = 1 + redcount (\"y" ~> (\"x" ~> `"x") $ `"z") + 1). simpl. reflexivity. rewrite M.
  apply nthred_conclplus. split.
    apply islam.
    apply nthred_prim.
Qed.

(** Beta-reduction and left-most reduction (Definition 2.2) **)

(* The paper defines beta-reduction in terms of the [nthred] relation.
   Equivalence with the definition found in [Beta] has yet to be proven (if necessary).
*)

Definition bet (t1 t2 : lterm) : Prop := exists n : nat, nthred n t1 t2.

Definition betstar := clos_refl_trans lterm bet.
Definition betstar_step := rt_step lterm bet.
Definition betstar_refl := rt_refl lterm bet.
Definition betstar_trans := rt_trans lterm bet.

(* Left-most reduction is simply reduction of the first redex. *)

Definition lmost (t1 t2 : lterm) : Prop := nthred 1 t1 t2.

Definition lstar := clos_refl_trans lterm lmost.
Definition lstar_step := rt_step lterm lmost.
Definition lstar_refl := rt_refl lterm lmost.
Definition lstar_trans := rt_trans lterm lmost.

(** Head-reduction in application (Definition 3.1) **)

Inductive hap' : lterm -> lterm -> Prop :=
  | hap'_hred : forall t0 t1, hap' (App (Lam t0) t1) (subst 0 t1 t0)
  | hap'_hreds : forall t0 t1 ta, hap' t0 t1 -> hap' (App t0 ta) (App t1 ta).

Inductive hap : lterm -> lterm -> Prop :=
  | hap_refl : forall t, hap t t
  | hap_hred : forall t0 t1, hap' t0 t1 -> hap t0 t1
  | hap_trans : forall t1 t2 t3, hap t1 t2 -> hap t2 t3 -> hap t1 t3.

(** Standard reduction (Definition 3.2) **)

Inductive st : lterm -> lterm -> Prop :=
  | st_hap : forall t i, hap t (Var i) -> st t (Var i)
  | st_hap_st_st : forall t t1 t2 t1' t2',
      hap t (App t1 t2) -> st t1 t1' -> st t2 t2' -> st t (App t1' t2')
  | st_haplam_st : forall t t1 t1',
      hap t (Lam t1) -> st t1 t1' -> st t (Lam t1').

(** Lemma 3.3 **)

(* (1) *)
Lemma hap_lstar : forall t1 t2, hap t1 t2 -> lstar t1 t2.
Proof.
  intros. induction H as [ t | t0 t1 | t1 t2 t3]. (*case H.*)
    (* hap_refl *)
    apply lstar_refl.
    (* hap_hred *)
    apply lstar_step. unfold lmost. induction H.
      apply nthred_prim.
      apply nthred_concr. split. unfold not. intro. induction H. inversion H0. inversion H0. assumption.
    (* hap_trans *)
    apply lstar_trans with (y := t2). apply IHhap1. apply IHhap2.
Qed.

(* (2) needs definition not yet introduced *)

(** Lemma 3.4 **)

(* (1) *)
Lemma st_refl : forall t, st t t.
Proof.
  intros t.
  induction t.
    apply st_hap. apply hap_refl.
    apply st_haplam_st with (t1 := t). apply hap_refl. assumption.
    apply st_hap_st_st with (t1 := t1) (t2 := t2). apply hap_refl. assumption. assumption.
Qed.

(* (2) *)
Lemma hap__app_hap : forall t1 t2 t3,
  hap t1 t2 -> hap (App t1 t3) (App t2 t3).
Proof.
  intros. induction H.
    apply hap_refl.
    apply hap_hred. apply hap'_hreds. assumption.
    apply hap_trans with (t2 := App t2 t3); assumption.
Qed.

(* (3) *)
Lemma hap_st__st : forall t1 t2 t3,
  hap t1 t2 -> st t2 t3 -> st t1 t3.
Proof.
  intros. induction H0.
    apply st_hap. apply hap_trans with (t2 := t). assumption. assumption.
    apply st_hap_st_st with (t1 := t0) (t2 := t2).
      apply hap_trans with (t2 := t); assumption.
      assumption. assumption.
    apply st_haplam_st with (t1 := t0).
      apply hap_trans with (t2 := t); assumption.
      assumption.
Qed.

(* (4) *)

(* We first prove [subst_hap'], after which the actual lemma is easy to show. *)

Lemma subst_hap' : forall t1 t2 t3, forall n,
  hap' t1 t2 -> hap' (subst n t3 t1) (subst n t3 t2).
Proof.
  intros. induction H.
    (* hap'_hred *)
    simpl.
    assert (EXP: subst n t3 (subst 0 t1 t0) = subst 0 (subst n t3 t1) (subst (n+1) t3 t0)).
      simpl. assert (T1: subst n t3 t1 = subst (n - 0) t3 t1).
        assert (T2: n = n - 0). omega. rewrite <- T2. reflexivity.
      rewrite T1. apply subst_lemma. omega.
    rewrite EXP. apply hap'_hred.
    (* hap'_hreds *)
    apply hap'_hreds. apply IHhap'.
Qed.

Lemma hap__hap_subst : forall t1 t2 t3,
  hap t1 t2 -> forall n : nat, hap (subst n t3 t1) (subst n t3 t2).
Proof.
  intros t1 t2 t3 H n. induction H.
    apply hap_refl.
    apply hap_hred. apply subst_hap'. assumption.
    apply hap_trans with (t2 := subst n t3 t2); assumption.
Qed.

(* We need to do quite a bit of busywork for (5). *)

(* First, lift-independence of [hap], which is easy. *)

Lemma lift_hap' : forall t t',
  hap' t t' -> forall n k, hap' (lift n k t) (lift n k t').
Proof.
  intros t t' H. induction H.
    (* hap'_hred *)
    intros n k. simpl.
    rewrite lift_subst_semicom. apply hap'_hred. omega.
    (* hap'_hreds *)
    intros n k. rewrite lift_app. rewrite lift_app. apply hap'_hreds. apply (IHhap' n).
Qed.

Lemma lift_hap : forall t t',
  hap t t' -> forall n k, hap (lift n k t) (lift n k t').
Proof.
  intros. induction H.
    (* hap_refl *)
    apply hap_refl.
    (* hap_hreds *)
    apply hap_hred. apply lift_hap'. assumption.
    (* hap_trans *)
    apply hap_trans with (t2 := lift n k t2); assumption.
Qed.

(* Second, lift-independence for [st], which is more intricate. *)

Lemma hap'_no_lhs_var : forall i t,
  ~ hap' (Var i) t.
Proof. intros. unfold not. intro H. inversion H. Qed.

Lemma hap_lefthandside_var : forall i t,
  hap (Var i) t -> t = Var i.
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
  apply hap_trans with (t2 := App (Lam (Var 4)) (Var 11)).
  apply hap_hred.
    apply hap'_hreds. apply hap'_hred.
    assert (Var 3 = subst 0 (Var 11) (Var 4)). reflexivity. rewrite H.
    apply hap_hred. apply hap'_hred.
Qed.

Lemma subst_to_var : forall t t' i,
  subst 0 t' t = Var i -> t = Var 0 /\ t' = Var i \/ t = Var (i + 1).
Proof.
  intros. induction t.
    (* Var *)
    inversion H. case_eq (Compare_dec.nat_compare n 0).
      (* Eq *)
      intros nEQ0. rewrite nEQ0 in H1. rewrite Compare_dec.nat_compare_eq_iff in nEQ0.
      left. split.
        f_equal. assumption.
        rewrite (lift_0_ident t' 0). reflexivity.
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

Lemma subst_indist : forall i r r',
  i > 0 -> subst 0 r (Var i) = subst 0 r' (Var i).
Proof.
  intros. simpl. rewrite Compare_dec.nat_compare_gt in H. rewrite H. reflexivity.
Qed.

(* This lemma is not yet fully established, there are two [admit]s.
   The first [admit] should be straightforward to eliminate (intuitively).
   Somehow the transitive evidence rule for [hap] makes it hard to show
   that [hap] does not hold between any two terms if the first is an
   abstraction, however.
*)

Lemma lift_first_hap : forall t n i k,
  hap t (Var i) -> i < k -> hap (lift n k t) (Var i).
Proof.
  intros t n i k H iLTk. dependent induction t.
  (* Var *)
  apply hap_lefthandside_var in H. rewrite <- H. simpl.
  case_eq (Compare_dec.lt_dec i k).
    intros. apply hap_refl.
    intros. contradiction.
  (* Lam *)
  inversion H. inversion H0. (* TODO how to handle these transitive cases? *) admit.
  (* App *)
  simpl. dependent induction H.
    dependent induction H.
      apply hap_hred. simpl.
      rewrite <- x.
      case (subst_to_var t0 t2 i). assumption.
        (* t2 = Var i *)
        intro HC. inversion HC as [Ht0 Ht2]. rewrite Ht2.
        assert (LFT: Var i = lift n k (Var i)). simpl. case_eq (Compare_dec.lt_dec i k).
          (* i < k *)
          intros. reflexivity.
          (* ~ i < k *)
          intros. contradiction.
        rewrite <- LFT.
        assert (IGN: t0 = lift n (k + 1) t0).
          rewrite Ht0. simpl. case_eq (Compare_dec.lt_dec 0 (k + 1)).
            (* 0 < k + 1 *)
            intros. reflexivity.
            (* ~ 0 < k + 1 *)
            intros. contradict iLTk. omega.
        rewrite <- IGN. apply hap'_hred.
        (* t0 = Var (i + 1) *)
        intro Hti1. rewrite Hti1.
        assert (INDIST: subst 0 t2 (Var (i+1)) = subst 0 (lift n k t2) (Var (i+1))).
          apply subst_indist. omega.
        rewrite INDIST.
        assert (IGN: lift n (k+1) (Var (i+1)) = Var (i+1)).
          simpl. case_eq (Compare_dec.lt_dec (i + 1) (k + 1)).
            (* i + 1 < k + 1 *)
            intros. reflexivity.
            (* ~ i + 1 < k + 1 *)
            intros FLS. contradict FLS. omega.
        rewrite IGN. apply hap'_hred.
      rewrite <- lift_app.
      apply IHhap1.
        apply IHt2.
        apply IHt1.
        admit. (* TODO this one is weird *)
        assumption.
 Qed.

Lemma lift_st : forall t t',
  st t t' -> forall n k, st (lift n k t) (lift n k t').
Proof.
  intros t t' H. dependent induction H.
    (* st_hap *)
    intros n k. simpl. case_eq (Compare_dec.lt_dec i k).
      (* i < k *)
      intros. apply st_hap. apply lift_first_hap; assumption.
      (* ~ i < k *)
      intros. apply st_hap.
      assert (FLD: Var (i + n) = lift n k (Var i)). simpl.
        case_eq (Compare_dec.lt_dec i k). intros. contradiction. intros. reflexivity.
      rewrite FLD. apply lift_hap. assumption.
    (* st_hap_st_st *)
    intros n k. apply st_hap_st_st with (t1 := lift n k t1) (t2 := lift n k t2).
    rewrite <- lift_app. apply lift_hap. assumption.
    fold lift. apply IHst1.
    fold lift. apply IHst2.
    (* st_haplam_st *)
    intros n k. apply st_haplam_st with (t1 := lift n (k+1) t1).
    rewrite <- lift_lam. apply lift_hap. assumption.
    fold lift. apply IHst.
Qed.

(* (5) *)
Lemma st_st__st_subst : forall t1 t2 t3 t4,
  st t1 t2 -> st t3 t4 -> forall n, st (subst n t3 t1) (subst n t4 t2).
Proof.
  intros t1 t2 t3 t4 HMN HPQ. induction HMN.
    (* hap with Var *)
    intro n.
    assert (hap (subst n t3 t) (subst n t3 t)). apply hap_refl.
    assert (hap (subst n t3 t) (subst n t3 (Var i))). apply hap__hap_subst. assumption.
    apply hap_st__st with (t2 := subst n t3 (Var i)). assumption.
    simpl. case_eq (Compare_dec.nat_compare i n).
      (* Eq *)
      intro. apply lift_st. assumption.
      (* Lt *)
      intro. apply st_hap. apply hap_refl.
      (* Gt *)
      intro. apply st_hap. apply hap_refl.
    (* hap with App *)
    intro n. rewrite subst_app.
    apply st_hap_st_st with (t1 := subst n t3 t1) (t2 := subst n t3 t2).
    rewrite <- subst_app.
    apply hap__hap_subst.
    assumption. apply (IHHMN1 n). apply (IHHMN2 n).
    (* hap with Lam *)
    intro n.
    apply st_haplam_st with (t1 := subst (n+1) t3 t1).
    rewrite <- subst_lam.
    apply hap__hap_subst.
    assumption.
    apply (IHHMN (n+1)).
Qed.