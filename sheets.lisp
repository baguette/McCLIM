;;; -*- Mode: Lisp; Package: CLIM-INTERNALS -*-

;;;  (c) copyright 1998,1999,2000 by Michael McDonald (mikemac@mikemac.com), 
;;;  (c) copyright 2000 by 
;;;           Iban Hatchondo (hatchond@emi.u-bordeaux.fr)
;;;           Julien Boninfante (boninfan@emi.u-bordeaux.fr)
;;;           Robert Strandh (strandh@labri.u-bordeaux.fr)

;;; This library is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU Library General Public
;;; License as published by the Free Software Foundation; either
;;; version 2 of the License, or (at your option) any later version.
;;;
;;; This library is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; Library General Public License for more details.
;;;
;;; You should have received a copy of the GNU Library General Public
;;; License along with this library; if not, write to the 
;;; Free Software Foundation, Inc., 59 Temple Place - Suite 330, 
;;; Boston, MA  02111-1307  USA.



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; The sheet protocol

(in-package :CLIM-INTERNALS)

(defgeneric sheet-parent (sheet)
  (:documentation
   "Returns the parent of the sheet SHEET or nil if the sheet has
no parent"))

(defgeneric sheet-children (sheet)
  (:documentation
   "Returns a list of sheets that are the children of the sheet SHEET.
Some sheet classes support only a single child; in this case, the
result of sheet-children will be a list of one element. This
function returns objects that reveal CLIM's internal state ; do not
modify those objects."))

(defgeneric sheet-adopt-child (sheet child)
  (:documentation
   "Adds the child sheet child to the set of children of the sheet SHEET,
and makes the sheet the child's parent. If child already has a parent, 
the sheet-already-has-parent error will be signalled.

Some sheet classes support only a single child. For such sheets, 
attempting to adopt more than a single child will cause the 
sheet-supports-only-one-child error to be signalled."))

(defgeneric sheet-disown-child (sheet child &key (errorp t)))
(defgeneric sheet-enabled-children (sheet))
(defgeneric sheet-ancestor-p (sheet putative-ancestor))
(defgeneric raise-sheet (sheet))

;;; not for external use
(defgeneric raise-sheet-internal (sheet parent))

(defgeneric bury-sheet (sheet))

;;; not for external use
(defgeneric bury-sheet-internal (sheet parent))

(defgeneric reorder-sheets (sheet new-ordering))
(defgeneric sheet-enabled-p (sheet))
(defgeneric (setf sheet-enabled-p) (enabled-p sheet))
(defgeneric sheet-viewable-p (sheet))
(defgeneric sheet-occluding-sheets (sheet child))

;;; not for external use
(defgeneric realize-hierarchy (sheet port))
(defgeneric realize-sheet (sheet port))
(defgeneric unrealize-hierarchy (sheet))
(defgeneric unrealize-sheet (sheet))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Sheet geometry

(defgeneric sheet-transformation (sheet))
(defgeneric (setf sheet-transformation) (transformation sheet))
(defgeneric sheet-region (sheet))
(defgeneric (setf sheet-region) (region sheet))
(defgeneric map-sheet-position-to-parent (sheet x y))
(defgeneric map-sheet-position-to-child (sheet x y))
(defgeneric map-sheet-rectangle*-to-parent (sheet x1 y1 x2 y2))
(defgeneric map-sheet-rectangle*-to-child (sheet x1 y1 x2 y2))
(defgeneric child-containing-position (sheet x y))
(defgeneric children-overlapping-region (sheet region))
(defgeneric children-overlapping-rectangle* (sheet x1 y1 x2 y2))
(defgeneric sheet-delta-transformation (sheet ancestor))
(defgeneric sheet-allocated-region (sheet child))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; input protocol

(defgeneric dispatch-event (client event))
(defgeneric queue-event (client event))
(defgeneric handle-event (client event))
(defgeneric event-read (client))
(defgeneric event-read-no-hang (client))
(defgeneric event-peek (client &optional event-type))
(defgeneric event-unread (client event))
(defgeneric event-listen (client))
(defgeneric sheet-direct-mirror (sheet))
(defgeneric sheet-mirrored-ancestor (sheet))
(defgeneric sheet-mirror (sheet))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; repaint protocol

(defgeneric dispatch-repaint (sheet region))
(defgeneric queue-repaint (sheet region))
(defgeneric handle-repaint (sheet medium region))
(defgeneric repaint-sheet (sheet region))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; notification protocol

(defgeneric note-sheet-grafted (sheet))
(defgeneric note-sheet-degrafted (sheet))
(defgeneric note-sheet-adopted (sheet))
(defgeneric note-sheet-disowned (sheet))
(defgeneric note-sheet-enabled (sheet))
(defgeneric note-sheet-disabled (sheet))
(defgeneric note-sheet-region-changed (sheet))
(defgeneric note-sheet-transformation-changed (sheet))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;
;;;; sheet protocol class

(defclass sheet ()
  ((region :initarg :region :accessor sheet-region)
   (enabled-p :initform nil :accessor sheet-enabled-p)))

(defun sheetp (x)
  (typep x 'sheet))

(defmethod sheet-parent ((sheet sheet))
  nil)

(defmethod set-sheets-parent ((sheet sheet) (parent sheet))
  (error "Attempting to set the parent of a sheet that has no parent"))

(defmethod sheet-children ((sheet sheet))
  nil)

(defmethod sheet-adopt-child ((sheet sheet) (child sheet))
  (error "SHEET attempting to adopt a child"))

(define-condition sheet-is-not-child (error) ())

(defmethod sheet-disown-child ((sheet sheet) (child sheet) &key (errorp t))
  (cond
   ((eq (sheet-parent child) sheet)
    (set-sheets-parent child nil)
    (setf (sheet-children sheet) (remove child (sheet-children sheet))))
   (errorp
    (error 'sheet-is-not-child)))
  child)

(defmethod sheet-siblings ((sheet sheet))
  (remove sheet (sheet-children (sheet-parent sheet))))

(defmethod sheet-enabled-children ((sheet sheet))
  (delete-if-not #'sheet-enabled-p (copy-list (sheet-children sheet))))

(defmethod sheet-ancestor-p ((sheet sheet) (putative-ancestor sheet))
  (eq sheet putative-ancestor))

(defmethod raise-sheet ((sheet sheet))
  (setf (sheet-children sheet) (cons sheet (remove sheet (sheet-children sheet))))
  sheet)

(defmethod bury-sheet ((sheet sheet))
  (setf (sheet-children sheet) (nconc (remove sheet (sheet-children sheet)) (list sheet)))
  sheet)

(define-condition sheet-ordering-underspecified (error) ())

(defmethod reorder-sheets ((sheet sheet) new-ordering)
  (when (set-difference (sheet-children sheet) new-ordering)
    (error 'sheet-ordering-underspecified))
  (when (set-difference new-ordering (sheet-children sheet))
    (error 'sheet-is-not-child))
  (setf (sheet-children sheet) new-ordering)
  sheet)

(defmethod sheet-viewable-p ((sheet sheet))
  (and (sheet-parent sheet)
       (sheet-viewable-p (sheet-parent sheet))
       (sheet-enabled-p sheet)))

(defmethod sheet-occluding-sheets ((sheet sheet) (child sheet))
  (labels ((fun (l)
		(cond ((eq (car l) child) '())
		      ((region-intersects-region-p
			(sheet-region (car l)) (sheet-region child))
		       (cons (car l) (fun (cdr l))))
		      (t (fun (cdr l))))))
    (fun (sheet-children sheet))))

(defmethod sheet-transformation ((sheet sheet))
  (error "Attempting to get the TRANSFORMATION of a SHEET that doesn't contain one"))

(defmethod (setf sheet-transformation) (transformation (sheet sheet))
  (declare (ignore transformation))
  (error "Attempting to set the TRANSFORMATION of a SHEET that doesn't contain one"))

(defmethod map-sheet-position-to-parent ((sheet sheet) x y)
  (declare (ignore x y))
  (error "Sheet has no parent"))

(defmethod map-sheet-position-to-child ((sheet sheet) x y)
  (declare (ignore x y))
  (error "Sheet has no parent"))

(defmethod map-sheet-rectangle*-to-parent ((sheet sheet) x1 y1 x2 y2)
  (declare (ignore x1 y1 x2 y2))
  (error "Sheet has no parent"))

(defmethod map-sheet-rectangle*-to-child ((sheet sheet) x1 y1 x2 y2)
  (declare (ignore x1 y1 x2 y2))
  (error "Sheet has no parent"))

(defmethod child-containing-position ((sheet sheet) x y)
  (loop for child in (sheet-children sheet)
      do (multiple-value-bind (tx ty) (map-sheet-position-to-child child x y)
	    (if (and (sheet-enabled-p child)
		     (region-contains-position-p (sheet-region child) tx ty))
		(return child)))))

(defmethod children-overlapping-region ((sheet sheet) (region region))
  (loop for child in (sheet-children sheet)
      if (and (sheet-enabled-p child)
	      (region-intersects-region-p 
	       region 
	       (transform-region (sheet-transformation child)
				 (sheet-region child))))
      collect child))

(defmethod children-overlapping-rectangle* ((sheet sheet) x1 y1 x2 y2)
  (children-overlapping-region sheet (make-rectangle* x1 y1 x2 y2)))

(defmethod sheet-delta-transformation ((sheet sheet) (ancestor (eql nil)))
  (cond ((sheet-parent sheet)
	 (compose-transformations (sheet-transformation sheet)
				  (sheet-delta-transformation
				   (sheet-parent sheet) ancestor)))
	(t (sheet-transformation sheet))))
  
(define-condition sheet-is-not-ancestor (error) ())

(defmethod sheet-delta-transformation ((sheet sheet) (ancestor sheet))
  (cond ((eq sheet ancestor) +identity-transformation+)
	((sheet-parent sheet)
	 (compose-transformations (sheet-transformation sheet)
				  (sheet-delta-transformation
				   (sheet-parent sheet) ancestor)))
	(t (error 'sheet-is-not-ancestor))))

(defmethod sheet-allocated-region ((sheet sheet) (child sheet))
  (reduce #'region-difference
	  (mapc #'(lambda (child)
		    (transform-region (sheet-transformation child)
				      (sheet-region child)))
		(cons child (sheet-occluding-sheets sheet child)))))

(defmethod sheet-direct-mirror ((sheet sheet))
  nil)

(defmethod sheet-mirrored-ancestor ((sheet sheet))
  (if (sheet-parent sheet)
      (sheet-mirrored-ancestor (sheet-parent sheet))))

(defmethod sheet-mirror ((sheet sheet))
  (let ((mirrored-ancestor (sheet-mirrored-ancestor sheet)))
    (if mirrored-ancestor
	(sheet-direct-mirror mirrored-ancestor))))

(defmethod graft ((sheet sheet))
  nil)

(defmethod graft ((sheet null))
  (values))

(defmethod note-sheet-grafted ((sheet sheet))
  nil)

(defmethod note-sheet-degrafted ((sheet sheet))
  nil)

(defmethod note-sheet-adopted ((sheet sheet))
  (when (sheet-grafted-p sheet)
    (note-sheet-grafted sheet)))

(defmethod note-sheet-disowned ((sheet sheet))
;  (when (sheet-grafted-p sheet)
  (note-sheet-degrafted sheet))

(defmethod note-sheet-region-changed ((sheet sheet))
  nil) ;have to change

(defmethod note-sheet-transformation-changed ((sheet sheet))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; sheet parent mixin


(defclass sheet-parent-mixin ()
  ((parent :initform nil :accessor sheet-parent)))


(defmethod set-sheets-parent ((child sheet-parent-mixin) (parent sheet))
  (setf (slot-value child 'parent) parent))

(define-condition sheet-already-has-parent (error) ())
(define-condition sheet-is-ancestor (error) ())

(defmethod sheet-adopt-child :before (sheet (child sheet-parent-mixin))
  (when (sheet-parent child) (error 'sheet-already-has-parent))
  (when (sheet-ancestor-p sheet child) (error 'sheet-is-ancestor)))

(defmethod sheet-adopt-child :after (sheet (child sheet-parent-mixin))
  (setf (sheet-parent child) sheet))

(defmethod sheet-disown-child :before (sheet
				       (child sheet-parent-mixin)
				       &key (errorp t))
  (when (and errorp (not (eq sheet (sheet-parent child))))
    (error 'sheet-is-not-child)))

(defmethod sheet-disown-child :after (sheet
				      (child sheet-parent-mixin)
				      &key (errorp t))
  (declare (ignore sheet errorp))
  (setf (sheet-parent child) nil))

(defmethod sheet-siblings ((sheet sheet-parent-mixin))
  (when (not (sheet-parent sheet))
    (error 'sheet-is-not-child))
  (remove sheet (sheet-children (sheet-parent sheet))))

(defmethod sheet-ancestor-p ((sheet sheet-parent-mixin)
			     (putative-ancestor sheet))
  (or (eq sheet putative-ancestor)
      (and (sheet-parent sheet)
	   (sheet-ancestor-p (sheet-parent sheet) putative-ancestor))))

(defmethod raise-sheet ((sheet sheet-parent-mixin))
  (when (not (sheet-parent sheet))
    (error 'sheet-is-not-child))
  (raise-sheet-internal sheet (sheet-parent sheet)))

(defmethod bury-sheet ((sheet sheet-parent-mixin))
  (when (not (sheet-parent sheet))
    (error 'sheet-is-not-child))
  (bury-sheet-internal sheet (sheet-parent sheet)))

(defmethod graft ((sheet sheet-parent-mixin))
  (graft (sheet-parent sheet)))

(defmethod (setf sheet-transformation) :after (newvalue (sheet sheet-parent-mixin))
  (declare (ignore newvalue))
  (note-sheet-transformation-changed sheet))

(defmethod map-sheet-position-to-parent ((sheet sheet-parent-mixin) x y)
  (transform-position (sheet-transformation sheet) x y))

(defmethod map-sheet-position-to-child ((sheet sheet-parent-mixin) x y)
  (transform-position (invert-transformation (sheet-transformation sheet)) x y))

(defmethod map-sheet-rectangle*-to-parent ((sheet sheet-parent-mixin) x1 y1 x2 y2)
  (transform-rectangle* (sheet-transformation sheet) x1 y1 x2 y2))

(defmethod map-sheet-rectangle*-to-child ((sheet sheet-parent-mixin) x1 y1 x2 y2)
  (transform-rectangle* (invert-transformation (sheet-transformation sheet)) x1 y1 x2 y2))

(defmethod raise-sheet ((sheet sheet-parent-mixin))
  (when (not (sheet-parent sheet))
    (error 'sheet-is-not-child))
  (raise-sheet-internal sheet (sheet-parent sheet)))

(defmethod bury-sheet ((sheet sheet-parent-mixin))
  (when (not (sheet-parent sheet))
    (error 'sheet-is-not-child))
  (bury-sheet-internal sheet (sheet-parent sheet)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; sheet leaf mixin

(defclass sheet-leaf-mixin () ())

(defmethod sheet-children ((sheet sheet-leaf-mixin))
  nil)

(defmethod sheet-adopt-child ((sheet sheet-leaf-mixin) (child sheet))
  (error "Leaf sheet attempting to adopt a child"))

(defmethod sheet-disown-child ((sheet sheet-leaf-mixin) (child sheet) &key (errorp t))
  (declare (ignorable errorp))
  (error "Leaf sheet attempting to disown a child"))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; sheet single child mixin

(defclass sheet-single-child-mixin ()
  ((children :initform nil :initarg :child :accessor sheet-children)))

(define-condition sheet-supports-only-one-child (error) ())

(define-condition sheet-already-has-parent (error) ())

(defmethod sheet-adopt-child :before ((sheet sheet-single-child-mixin)
				      child)
  (declare (ignorable child))
  (when (sheet-children sheet) (error 'sheet-supports-only-one-child))
  (when (sheet-parent child) (error 'sheet-already-has-parent)))

(defmethod sheet-adopt-child ((sheet sheet-single-child-mixin)
			      (child sheet-parent-mixin))
  (setf (sheet-children sheet) child))

(defmethod sheet-adopt-child :after ((sheet sheet-single-child-mixin)
				     (child sheet-parent-mixin))
  (declare (ignorable sheet))
  (note-sheet-adopted child))

(defmethod sheet-disown-child ((sheet sheet-single-child-mixin)
			       (child sheet-parent-mixin)
			       &key (errorp t))
  (declare (ignorable errorp))
  (setf (sheet-children sheet) nil))

(defmethod sheet-disown-child :after ((sheet sheet-single-child-mixin)
				      (child sheet-parent-mixin)
				      &key (errorp t))
  (declare (ignorable sheet errorp))
  (note-sheet-disowned child))

(defmethod reorder-sheets ((sheet sheet-single-child-mixin) new-order)
  (declare (ignorable sheet new-order))
  nil)

(defmethod raise-sheet-internal (sheet (parent sheet-single-child-mixin))
  (declare (ignorable sheet parent))
  (values))

(defmethod bury-sheet-internal (sheet (parent sheet-single-child-mixin))
  (declare (ignorable sheet parent))
  (values))

(defmethod note-sheet-grafted ((sheet sheet-single-child-mixin))
  (note-sheet-grafted (first (sheet-children sheet))))

(defmethod note-sheet-degrafted ((sheet sheet-single-child-mixin))
  (note-sheet-degrafted (first (sheet-children sheet))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; sheet multiple child mixin

(defclass sheet-multiple-child-mixin ()
  ((children :initform nil :initarg :children :accessor sheet-children)))

(defmethod sheet-adopt-child ((sheet sheet-multiple-child-mixin)
			      (child sheet-parent-mixin))
  (when (sheet-parent child)
    (error 'sheet-already-has-parent))
  (push child (sheet-children sheet)))

(defmethod sheet-adopt-child :after ((sheet sheet-multiple-child-mixin)
				     (child sheet-parent-mixin))
  (declare (ignorable sheet))
  (note-sheet-adopted child))

(defmethod sheet-disown-child ((sheet sheet-multiple-child-mixin)
			       (child sheet-parent-mixin)
			       &key (errorp t))
  (declare (ignorable errorp))
  (setf (sheet-children sheet) (delete child (sheet-children sheet))))

(defmethod sheet-disown-child :after ((sheet sheet-multiple-child-mixin)
				     (child sheet-parent-mixin)
				     &key (errorp t))
  (declare (ignorable sheet errorp))
  (note-sheet-disowned child))

(defmethod raise-sheet-internal (sheet (parent sheet-multiple-child-mixin))
  (setf (sheet-children parent)
	(cons sheet (delete sheet (sheet-children parent)))))

(defmethod bury-sheet-internal (sheet (parent sheet-multiple-child-mixin))
  (setf (sheet-children parent)
	(append (delete sheet (sheet-children parent)) (list  sheet))))

(defmethod note-sheet-grafted ((sheet sheet-multiple-child-mixin))
  (mapcar #'note-sheet-grafted (sheet-children sheet)))

(defmethod note-sheet-degrafted ((sheet sheet-multiple-child-mixin))
  (mapcar #'note-sheet-degrafted (sheet-children sheet)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; sheet geometry classes

(defclass sheet-identity-transformation-mixin ()
  ((transformation :initform +identity-transformation+
		   :reader sheet-transformation)))

(defclass sheet-translation-transformation-mixin ()
  ((transformation :initform +identity-transformation+
		   :initarg :transformation
		   :accessor sheet-transformation)))

(defmethod (setf sheet-transformation) :before ((transformation transformation)
						(sheet sheet-translation-transformation-mixin))
  (if (not (translation-transformation-p transformation))
      (error "Attempting to set the SHEET-TRANSFORMATION of a SHEET-TRANSLATION-TRANSFORMATION-MIXIN to a non translation transformation")))

(defclass sheet-y-inverting-transformation-mixin ()
  ((transformation :initform (make-transformation 0 0 0 -1 0 0)
		   :initarg :transformation
		   :accessor sheet-transformation)))

(defmethod (setf sheet-transformation) :before ((transformation transformation)
						(sheet sheet-y-inverting-transformation-mixin))
  (if (not (y-inverting-transformation-p transformation))
      (error "Attempting to set the SHEET-TRANSFORMATION of a SHEET-Y-INVERTING-TRANSFORMATION-MIXIN to a non Y inverting transformation")))

(defclass sheet-transformation-mixin ()
  ((transformation :initform +identity-transformation+
		   :initarg :transformation
		   :accessor sheet-transformation)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; mirrored sheet

(defclass mirrored-sheet (sheet)
  ((port :initform nil :initarg :port :accessor port)))

(defmethod sheet-direct-mirror ((sheet mirrored-sheet))
  (port-lookup-mirror (port sheet) sheet))

(defmethod sheet-mirrored-ancestor ((sheet mirrored-sheet))
  sheet)

(defmethod note-sheet-grafted :before ((sheet mirrored-sheet))
  (realize-mirror (port sheet) sheet))

(defmethod note-sheet-degrafted :after ((sheet mirrored-sheet))
  (unrealize-mirror (port sheet) sheet))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; repaint protocol classes

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; standard repaint mixin

(defclass standard-repaint-mixin () ())

(defmethod dispatch-repaint ((sheet standard-repaint-mixin) region)
  (queue-repaint sheet region))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; immediate repaint mixin

(defclass immediate-repaint-mixin () ())

(defmethod dispatch-repaint ((sheet immediate-repaint-mixin) region)
  (handle-repaint sheet nil region))

(defmethod handle-repaint ((sheet immediate-repaint-mixin) medium region)
  (declare (ignore medium region))
  (repaint-sheet sheet (sheet-region sheet))
  (loop for child in (sheet-children sheet)
	for region = (sheet-region child)
	do (repaint-sheet child region)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; mute repaint mixin

(defclass mute-repaint-mixin () ())

(defmethod dispatch-repaint ((sheet mute-repaint-mixin) region)
  (handle-repaint sheet nil region))

(defmethod dispatch-repaint ((sheet standard-repaint-mixin) region)
  (queue-repaint sheet region))

(defmethod repaint-sheet ((sheet mute-repaint-mixin) region)
  (declare (ignorable sheet region))
  (values))
