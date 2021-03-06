;;; -*- Mode: LISP; Syntax: Common-lisp; Package: Meta-aqua; Base: 10 -*-

(in-package :metaaqua)


(defvar *within-IDE* nil
  "When t the Allegro IDE development environment is running")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 
;;; The following two functions exist in understander.lisp in stub
;;; form. Function test-applicable-p used to simply return nil, whereas
;;; devise-test had a format call stating that the code should not have been
;;; executed. This file implements them to verify an xp by checking for
;;; reasonableness of the xp-asserted nodes. We should really call these
;;; functions by another name, but to do so I will have to create another
;;; hypothesis-verification-choice-value (perhaps check-antecedents.0).
;;; 
;;; Also in this file are two other functions from understander.lisp. They are
;;; v.strategy-decision and v.runstrategy and are redefined at the bottom of
;;; this file.
;;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; 
;;; Predicate test-applicable-p takes a hypothesis and returns whether or not a
;;; test can be devised (or is it worth for the system to try an devise a test)
;;; for the hypothesis. Currently we test this by trying to generate matches
;;; for the antecedents of the hypothesis XP.
;;; 
;;; If this function returns t, then the match is trivial (i.e., no xp-asserted
;;; nodes exist on the xp and it is always true. Otherwise it returns the match
;;; or nil.
;;; 
(defun test-applicable-p (hypothesis
			  &aux
			  (antecedents 
			   (f.get hypothesis 
				  *asserted-node-slot*))
			  matches	;list
			  )
  (format t "~%~s is the hypothesis.~%" 
	  hypothesis)
  (setf matches				;This assignment performed second
    (append 
     (setf matches			;This assignment performed first
       (mapcan #'exists-in-story2
	       antecedents))
     (mapcan #'find-compatible-scripts 
	     (set-difference 
	      antecedents		;Use only unmatched antecedents
	      (mapcar #'first 
		      matches)		;This uses the first assignment
	      ))))
  (or matches
      (null antecedents))
  )


;;; 
;;; This routine will try to verify the xp-asserted nodes of the hypothesis. If
;;; it is called, then the matches will have already been generated by the
;;; test-applicable-p predicate. The match list will be available on the
;;; verify-node. This strategy is similar to that of the compare procedure (or
;;; the explain procedure itself for that matter).
;;; 
;;; The devise-test name is misleading. Originally it had been intended as a
;;; function that would create a verification strategy. I am using it for a
;;; different purpose, because it is already called at the right place if
;;; test-applicable-p returns non-nil.
;;; 
;;; Added verify-node parameter. Added return vaue of mentally-initiates
;;; structure. [mcox 14nov06]
;;; 
(defun devise-test (matches		;list
		    hypothesis 
		    k-goal
		    verify-node
		    &aux
		    (antecedents 
		     (f.get hypothesis 
			    *asserted-node-slot*))
		    (exists-match	;boolean
		     (not 
		      (null matches)))
		    (trivial-match	;boolean
		     (eq t matches))
		    full-match		;boolean
		    )
  (format
   *aqua-window*
   "~%devise-test has parameters ~s and ~s.~%~%"
   hypothesis k-goal)
  (if exists-match
      (cond (trivial-match
	     (format 
	      t 
	      "~%Explanation succeeds trivially because no antecedents.~%")
	     )
	    ((eql (length antecedents)		;if all antecedents matched
		  (length matches))
	     (setf full-match t)
	     (unify-antecedents matches))
	))
  (cond (*within-IDE*
	 (inspect (symbol-value hypothesis))
	 (break "Examine explanation hypothesis ~%Antecedents: ~S~%Matches: ~s~%"
		antecedents matches))
	(t
	 (pprint hypothesis t)
	 ;;(y-or-n-p "Enter y to continue ")
	 ))
  (cond (exists-match
	 (remove-achieved-goal k-goal)
	 (assert-truth
	  *in*
	  (let ((match-mapping
		 (map-antecedents-2-matches 
		  antecedents matches)))
	    (f.instantiate-frame
	     `(mentally-initiates
	       (results- (,*value-facet*
			  ,verify-node))
	       (,*domain-slot*
		(,*value-facet*
		 (equal-relation
		  (,*domain-slot*
		   (,*value-facet* ,match-mapping))
		  (,*co-domain-slot*
		   (,*value-facet* ,antecedents)))))
	       (,*co-domain-slot*
		(,*value-facet* 
		 (,(if (or trivial-match
			   full-match)
		       'successful-verification
		     'partial-verification)
		  (initiates- (,*value-facet* =domain))
		  (expected-outcome
		   (,*value-facet* ,antecedents))
		  (actual-outcome
		   (,*value-facet* ,match-mapping)))))
	       ))))
	 )
	(t 
	 ;;(f.put! 'suspension.0 
	 ;;        (f.chase-path k-goal 'mxp 'examination) 'strategy-choice)
	 (suspend-task hypothesis k-goal)
	 ))
  )


;;; 
;;; For each antecedent, map to the corresponding match with the highest
;;; similarity. Assoc might work instead, but will stay with this.
;;; 
;;; (map-antecedents-2-matches 
;;;   '(a1 a2) 
;;;   '((a2 (x 0.75)(y 0.8)(z 0.4))(a1 (q 0.3)(r 0.1))))
;;; --> (q y)
;;; 
(defun map-antecedents-2-matches (antecedents matches)
  "Maps antecedents to their corresponding matches of greatest similarity"
  (mapcar #'(lambda (each-antecedent)
	      (first 
	       (first
		(sort
		 (rest 
		  (first
		   (member each-antecedent
			   matches
			   :test
			   #'(lambda (x y)
			       (equal x (first y))))))
		 #'>
		 :key
		 #'second)))
	      )
	  antecedents)
  )



;;  (mapcar #'(lambda (each-script)
;;	      (if (or (f.get each-script 'main-precondition)
;;		      (f.chase-path each-script 'instrumental-scene 'main-precondition))
;;		  each-script))
;;	  *script-list*)

;;; 
;;; Function find-compatible-scripts takes a target such as the hypothesized
;;; script from XP-RESERVATION-PRECOND->ACTOR and searches for a known script
;;; that has a main-precondition slot and can unify with it. A list of scripts
;;; meeting these constraints is returned.
;;; 
(defun find-compatible-scripts 
    (target-script
     &aux
     (matches
      (mapcan 
       #'(lambda (each-script
		  &aux 
		  similarity)
	   (when (and (f.get each-script 
			     'main-precondition)
		      (can-unify-p target-script 
				   each-script))
	     (format
	      *aqua-window*
	      "~%Hypothesized node ~s matches script ~s with similarity ~s"
	      target-script
	      each-script
	      (setf similarity
		(similarity-between 
		 (*frame* target-script) 
		 (*frame* each-script))))
	       (list 
		(list each-script 
		      similarity))))
       *script-list*)))
  (if matches
      (list (cons target-script
		  matches)))
  )


;;; 
;;; Sample matches argument is
;;; 
;;; ((ACHIEVEMENT-GOAL.25870 (ACHIEVEMENT-GOAL.23033 0.75))
;;;  (SCRIPT.25857 (VACATION-SCRIPT.1497 0.59375) (DINING-SCRIPT.1590 0.65)))
;;; 
;;; where the head of each element is an antecedent from an XP to be unified
;;; with one of the possible items in the tail.
;;; 
;;; Expands the match set into all possible match combinations (change later to
;;; expand incrementally). Then try to unify all antecedents with
;;; candidates. When a successful unification is found, do the unification for
;;; real. The function can-unify-candidate attempts to unify with a copy of the
;;; antecedent. We use a copy because unification is not reversable with the
;;; tools Meta-AQUA currently provides.
;;; 
(defun unify-antecedents (matches)
  (format t "~%~%Successfull explanation!")
  (format t "~%All antecedents match:~%~s~%"
	  matches)
  (some #'(lambda (candidate-matches)
	    (if (can-unify-candidate
		 candidate-matches)
		(do-unify-candidate
		    candidate-matches))
	    )
	(expand-matches
	 matches))
  
  )


;;; 
;;; Try to unify copies of all antecedents with candidates from the input list.
;;; 
(defun can-unify-candidate (candidate-list)
  (every  #'(lambda (each-pair)
	      (f.unify
	       (f.copy-instantiated-frame
		(first each-pair))
	       (f.copy-instantiated-frame
		(second each-pair))
	       :notify-but-no-break
	       ))
	  candidate-list)
  )


;;; 
;;; Unify every antecedent with matches from the input list. Guaranteed that
;;; unification will work because can-unify-candidate was called previously.
;;; 
(defun do-unify-candidate (candidate-list)
  (every  #'(lambda (each-pair)
	      (f.unify
	       (first each-pair)
	       (second each-pair)
	       :notify-but-no-break
	       ))
	  candidate-list)
  )


;;; 
;;; This is so awkward, but it works.
;;; 
(defun expand-matches (matches
		       &optional
		       preceding-expansions
		       &aux
		       temp)
  (cond ((null matches)
	 preceding-expansions)
	((null preceding-expansions)
	 (dolist (each-option 
		     ;; Need to sort options in reverse order 
		     ;; so that cons will order correctly.
		     (rest (first matches)))
	    (setf temp
	      (cons
	       (list
		(list (first (first matches))
		      (first each-option)))
	       temp)))
	 (expand-matches
	  (rest matches)
	  temp
	  ))
	(t
	 (dolist (each-option 
		     ;; Need to sort options here too.
		     (rest (first matches)))
	   (dolist (each-expansion
		       preceding-expansions)
	     (setf temp
	       (cons
		(append each-expansion
			(list 
			 (list (first (first matches))
			       (first each-option))))
		temp
		))))
	 (expand-matches
	  (rest matches)
	  temp)))
  )


;;; 
;;; Function exists-in-story2 finds the first similar concept in the world
;;; model that can unify with the assertion. If multiple possible matches
;;; exist, is there a better one? The function only returns the first match
;;; found. Matches are represented by a list whose head is the assertion and
;;; tail is a list of pairs. Each pair is a matching concept and its similarity
;;; to the assertion.
;;; 
(defun exists-in-story2 (assertion
			 &aux
			 similarity)
  (let ((match nil))
    (some
     #'(lambda (each-world-concept)
	 (when
	     (and (can-unify-p
		   each-world-concept
		   assertion)
		  (not 
		   (equal 
		    0.0 
		    (setf similarity
		      (similarity-between
		       (*FRAME* assertion )
		       (*FRAME* each-world-concept))))))
	   (format
	    *aqua-window*
	    "~%Hypothesized node ~s matches ~s in world model with similarity ~s"
	    assertion 
	    each-world-concept 
	    similarity)
	   (setf match 
	     (list 
	      assertion
	      (list 
	       each-world-concept 
	       similarity))
	   )))
     (get-model *World-Model*))
    (if match
	(list match)))
  )


(defun num-slots (f)
  "Returns the number of slots in frame f"
  (length (frame->slots f))
  )


;;; 
;;; What fraction of slots from f1 are in f2? Here we only care is they share a
;;; slot regardless of the slot values.
;;; 
(defun shared-slots-from 
    (f1 f2
     &aux
     (f1-role-number
      ;; More efficient to use this than frame->roles
      (num-slots f1)))
  (if (eql 0 f1-role-number)
      ;; Do not divide by zero.
      0
    (/ (length 
	(intersection (frame->roles f1)
		      (frame->roles f2)))
       f1-role-number))
  )


;;; What is the function in lisp ?
(defun average (x y)
  (/ (+ x y) 2)
  )


#|
(similarity-between (*frame* XP-RESERVATION-PRECOND->ACTOR.2362) 
		    (*frame* XP-RESERVATION-PRECOND->ACTOR.2362) )
1
(similarity-between (*frame* XP-RESERVATION-PRECOND->ACTOR.2362) 
		    (*frame* XP-INSTRUMENTAL-SCENE->ACTOR2.266))
779/968
(similarity-between (*frame* XP-RESERVATION-PRECOND->ACTOR.2362) 
		    (*frame* SCRIPT.2376))
25/968
|#

;;; 
;;; Function similarity-between returns the quantitative value for the
;;; similarity between two frames. This number is calculated from the average
;;; between the fraction of f1 slots shared by frame f2 and the fraction of f2
;;; slots shared by f1. This average is then biased by the ratio of the
;;; differences in the sizes of the frames. If two frames share all slots, then
;;; the similarity is ((1+1)/2)(1/1). To make this better, we should
;;; recursively calculate the similarity of the values of shared slots.
;;;
(defun similarity-between (f1 f2
			   &optional
			   (suppress-bias t)
			   &aux
			   (f1-slot-number
			    (num-slots f1))
			   (f2-slot-number
			    (num-slots f2))
			   )
  "Return a quantitative value for the similarity between two frames"
  (coerce  
   (* (average (shared-slots-from f1 f2)
	       (shared-slots-from f2 f1))
      (if suppress-bias
	  1
	(if (or (eql 0 f1-slot-number)
		(eql 0 f2-slot-number))
	    0				;No divide by zero
	  (if (< f1-slot-number 
		 f2-slot-number)
	      (/ f1-slot-number 
		 f2-slot-number)
	    (/ f2-slot-number 
	       f1-slot-number)))))
   'float)
  )


;;; 
;;; This change to the function may be moot now.... Original function is
;;; contained in file understander.lisp.
;;; 
(defun v.strategy-decision (decision-basis hypothesis verify-node k-goal)
  (let ((relevant-input (find-relevant-input
			  hypothesis))
	(k-state (f.instantiate-frame
		   knowledge-state))
	(return-val nil))
    (cond (relevant-input
	   (format
	     *aqua-window*
	     (str-concat
	       "~%Found relevant input "
	       "for verifying hypothesis: ~s~%")
	     relevant-input)
	   (format
	     *aqua-window*
	       "~%Comparison strategy selected ~%")
	   (do-break v.strategy-decision)
	   (f.unify
	     relevant-input
	     (f.get
	       k-state
	       'believed-item))
	   (setf return-val 'comparison.0))
	  
	  ((and 
	    ;; Check first to make sure decsion has not previously been set. 
	    ;; Could have been set by previous unsuccessful attempt to verify 
	    ;; xp with devise test. [mcox 2nov06]
	    (not (eq 'suspension.0 
		     (f.get verify-node 'strategy-choice)))
	    (setf relevant-input
	      (test-applicable-p hypothesis)))
	   (f.unify
	    (f.instantiate-frame 
	     `(entity 
	       (literal-val
		(value ,(f.instantiate-literal
			 relevant-input)))))
	    (f.get
	     k-state
	     'believed-item)
	    ;; Lazy unification of literal with an entity. [mcox 15nov06]
	    t t t)
	   (setf return-val 'devise-test.0))
	  (t
	   (setf return-val 'suspension.0)))
    (f.unify k-state
	     (or
	       (first
		 (f.chase-path
		   decision-basis
		   'knowledge
		   'members))
	       (first decision-basis)))
    return-val)
  )



(defun v.runstrategy (verify-node choice hypothesis k-goal)
  (f.unify (f.get verify-node 'main-result)
	 (f.instantiate-frame outcome))
  (case choice
    (comparison.0
      (f.put! (list (compare
		      (f.get
			(first
			  (return-decision-basis
			    verify-node))
			'believed-item)
		      hypothesis
		      k-goal
		      verify-node))
	      (f.get verify-node 'main-result)
	      'members)
      'compare.0)
    (devise-test.0
     (f.put! (list (devise-test 
		    ;; The following will retrieve the matches computed by the 
		    ;; predicate test-applicable-p and previously placed in 
		    ;; the literal frame. This is a bit of a hack, because
		    ;; I made up a slot called 'literal-val for the literal. It
		    ;; would not otherwise unify with the entity that was the 
		    ;; default value of the knowledge-goal's believed-item.
		    (*FRAME* 
		     (f.get 
		      (f.get
		       (first
			(return-decision-basis
			 verify-node))
		       'believed-item)
		      'literal-val))
		    hypothesis
		    k-goal 
		    ;; Added parameter [mcox 14nov06]
		    verify-node))
	      (f.get verify-node 'main-result)
	      'members)
      'devise-test.0)
    (suspension.0
      (suspend-task hypothesis k-goal)
      'suspend-task.0)
    ( t (format
	  *aqua-window*
	  "ERROR: unknown v-strategy - ~s." choice))))

