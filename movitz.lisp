;;;;------------------------------------------------------------------
;;;; 
;;;;    Copyright (C) 20012000, 2002-2004,
;;;;    Department of Computer Science, University of Tromso, Norway
;;;; 
;;;; Filename:      movitz.lisp
;;;; Description:   
;;;; Author:        Frode Vatvedt Fjeld <frodef@acm.org>
;;;; Created at:    Mon Oct  9 20:52:58 2000
;;;; Distribution:  See the accompanying file COPYING.
;;;;                
;;;; $Id: movitz.lisp,v 1.3 2004/01/16 12:02:05 ffjeld Exp $
;;;;                
;;;;------------------------------------------------------------------

(in-package movitz)

(defvar *i* nil)			; These hold the previous built images,
(defvar *ii* nil)			; for interactive use.

(defvar *image*)

(define-unsigned lu16 2 :little-endian)
(define-unsigned lu32 4 :little-endian)

(defconstant +code-vector-word-offset+ 2)
(defconstant +movitz-multiple-values-limit+ 127)

(defvar *bq-level* 0)
(defvar *default-image-init-file* #p"losp/los0.lisp")
(defvar *default-image-file* #p"los0-image")

(defmacro with-movitz-syntax (options &body body)
  (declare (ignore options))
  `(let ((*readtable* (copy-readtable)))
     (set-dispatch-macro-character #\# #\'
				   (lambda (stream subchar arg)
				     (declare (ignore subchar arg))
				     (list 'muerte.common-lisp::function
					   (read stream t nil t))))
     (set-macro-character #\` (lambda (stream char)
				(declare (ignore char))
				(let ((*bq-level* (1+ *bq-level*)))
				  (list 'muerte::movitz-backquote (read stream t nil t)))))
     (set-macro-character #\, (lambda (stream char)
				(declare (ignore char))
				(assert (plusp *bq-level*) ()
				  "Comma not inside backquote.")
				(let* ((next-char (read-char stream t nil t))
				       (comma-type (case next-char
						     (#\@ 'backquote-comma-at)
						     (#\. 'backquote-comma-dot)
						     (t (unread-char next-char stream)
							'backquote-comma))))
				  (list comma-type (read stream t nil t)))))
     ,@body))

(defun un-backquote (form level)
  "Dont ask.."
  (declare (notinline un-backquote))
  (assert (not (minusp level)))
  (values
   (typecase form
     (null nil)
     (list
      (case (car form)
	(backquote-comma
	 (cadr form))
	(t (cons 'append
		 (loop for sub-form-head on form
		     as sub-form = (and (consp sub-form-head)
					(car sub-form-head))
		     collecting
		       (cond
			((atom sub-form-head)
			 (list 'quote sub-form-head))
			((atom sub-form)
			 (list 'quote (list sub-form)))
			(t (case (car sub-form)
			     (muerte::movitz-backquote
			      (list 'list
				    (list 'list (list 'quote 'muerte::movitz-backquote)
					  (un-backquote (cadr sub-form) (1+ level)))))
			     (backquote-comma
			      (cond
			       ((= 0 level)
				(list 'list (cadr sub-form)))
			       ((and (listp (cadr sub-form))
				     (eq 'backquote-comma-at (caadr sub-form)))
				(list 'append
				      (list 'mapcar
					    '(lambda (x) (list 'backquote-comma x))
					    (cadr (cadr sub-form)))))
			       (t (list 'list
					(list 'list
					      (list 'quote 'backquote-comma)
					      (un-backquote (cadr sub-form) (1- level)))))))
			     (backquote-comma-at
			      (if (= 0 level)
				  (cadr sub-form)
				(list 'list
				      (list 'list
					    (list 'quote 'backquote-comma-at)
					    (un-backquote (cadr sub-form) (1- level))))))
			     (t (list 'list (un-backquote sub-form level)))))))))))
     (array
      (error "Array backquote not implemented."))
     (t (list 'quote form)))))

(defmacro muerte::movitz-backquote (form)
  (un-backquote form 0))

#+allegro
(excl:defsystem :movitz ()
  (:serial
   "movitz"
   "parse"
   "eval"
   "multiboot"
   "bootblock"
   "environment"
   "compiler-types"
   (:definitions "compiler-protocol"
       "storage-types")
   "image"
   "stream-image"
   "procfs-image"
   "assembly-syntax"
   (:definitions "compiler-protocol"
       (:parallel "compiler" "special-operators" "special-operators-cl"))))

#+allegro
(progn
  (defun muerte.common-lisp::package-name (package)
    (package-name package))
  (defun muerte.cl:find-package (name)
    (find-package name)))
