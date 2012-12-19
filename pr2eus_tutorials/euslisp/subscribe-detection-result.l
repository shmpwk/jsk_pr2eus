#!/usr/bin/env roseus
;;;;
;;;; send robot joint angle-vector to pr2 robot
;;;;
(defvar *typename* "perception_result")

;; $B%Q%C%1!<%8FI$_9~$_(B
(ros::roseus-add-msgs "posedetection_msgs")
(load "package://pr2eus/pr2-interface.l")
(ros::roseus "sub_detection_result")

;;$BLp0uFI$_9~$_(B
(load "models/arrow-object.l")
(setq *ar* (arrow))

;; transform listener
(setq *tfl* (instance ros::transform-listener :init))

(setq *cds* nil)
(defun objectdetection-cb (type msg)
  (let (frame-id (obj (car (send msg :objects))))
    (describe obj)
    (when (and obj
               (string= type (send obj :type)))
      (let ((fid (send msg :header :frame_id)))
        (if (and fid
                 (/= (elt fid 0) #\/))
            (setq frame-id (concatenate string "/" fid))
          (setq frame-id fid)))

      (setq *cds*
            (send *tfl* :lookup-transform
                  "/base_footprint" frame-id (send msg :header :stamp)))
      (when *cds*
        (send *cds* :transform (ros::tf-pose->coords (send obj :pose))))
      )
    ))

(ros::subscribe "ObjectDetection" posedetection_msgs::ObjectDetection
                #'objectdetection-cb *typename*)

(pr2)
(if (not (boundp '*irtviewer*)) (make-irtviewer))
(setq *ri* (instance pr2-interface :init))
;;(send *pr2* :reset-pose)
;;$B%\!<%I$N:BI8(B
(send *pr2* :angle-vector (send *ri* :state :potentio-vector))
(objects (list *pr2* *ar*))
(send *irtviewer* :draw-objects)

(defun proc-detection (&optional (max-count 100))
  (let ((counter 0))
    (setq *cds* nil)
    (ros::rate 10)
    (while t
      (ros::spin-once)
      (when *cds*
        (return-from proc-detection *cds*))
      (if (> counter max-count) (return-from proc-detection))
      (incf counter)
      (ros::sleep))
    ))

#|
;;
;;
(let (cds)
  (setq cds (proc-detection))
  (when cds
    (send *ar* :reset-pose)
    (send *ar* :transform cds)
    (send *pr2* :head :look-at cds)
    (send *pr2* :larm :inverse-kinematics cds)
    (send *irtviewer* :draw-objects))
  )
|#