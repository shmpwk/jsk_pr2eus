(require :unittest "lib/llib/unittest.l")
(load "package://pr2eus/pr2-interface.l")

(init-unit-test)

(pr2-init)

(deftest test-angle-vector
  (let (av0 av1 av2)
    (setq *ri* (instance pr2-interface :init))
    (assert (setq av0 (send *pr2* :reset-pose)))
    (send *pr2* :larm :shoulder-p :joint-angle 0)
    (assert (setq av1 (send *pr2* :angle-vector)))
    (send *pr2* :rarm :shoulder-p :joint-angle 0)
    (assert (setq av2 (send *pr2* :angle-vector)))
    (assert (send *ri* :angle-vector av1 2000))

    ;; (length avs) > (length tms)
    (assert (send *ri* :angle-vector-sequence (list av2 av0) 2000))
    ;; (length avs) = (length tms)
    (assert (send *ri* :angle-vector-sequence (list av0 av1) (list 2000 3000)))
    ;; (length avs) < (length tms)
    (assert (send *ri* :angle-vector-sequence (list av0 av1) (list 1000 2000 3000)))
    ))

(deftest test-angle-vector-limb
  (let (av0 av1 av2)
    (setq *ri* (instance pr2-interface :init))
    (assert (setq av0 (send *pr2* :reset-pose)))
    (send *pr2* :larm :shoulder-p :joint-angle 0)
    (assert (setq av1 (send *pr2* :angle-vector)))
    (send *pr2* :rarm :shoulder-p :joint-angle 0)
    (assert (setq av2 (send *pr2* :angle-vector)))
    (assert (send *ri* :angle-vector av1 2000 :larm-controller))
    (assert (send *ri* :angle-vector-sequence (list av2 av0) 2000 :larm-controller))
    ))

(deftest test-angle-vector-duration
  (let (tm)
    (setq *ri* (instance pr2-interface :init))
    (assert (send *pr2* :reset-pose))
    (assert (send *ri* :angle-vector (send *pr2* :angle-vector)))
    (send *ri* :wait-interpolation)
    (assert (= (send *ri* :angle-vector-duration (send *ri* :state :potentio-vector) (send *pr2* :angle-vector) 5 1.0) 1))
    (send *pr2* :larm :shoulder-p :joint-angle 0)
    (setq tm (send *ri* :angle-vector-duration (send *ri* :state :potentio-vector) (send *pr2* :angle-vector) 5 1.0 :larm-controller))
    (assert (> tm 1))
    (setq tm (send *ri* :angle-vector-duration (send *ri* :state :potentio-vector) (send *pr2* :angle-vector) 5 1.0 :rarm-controller))
    (assert (eps= tm 1.0))
    ))

;; https://github.com/jsk-ros-pkg/jsk_pr2eus/pull/165#discussion_r37421484
(deftest test-go-pos
  (let ()
    (setq *ri* (instance pr2-interface :init))
    (assert (send *ri* :go-pos 1 0 0) "(send *ri* :go-pos 1 0 0)") ;; go-pos is relative to current position
    (assert (send *ri* :go-pos 0 1 90) "(send *ri* :go-pos 0 1 90)")
    (assert (send *ri* :go-pos-no-wait -1 1 -90) "(send *ri* :go-pos-no-wait -1 1 -90)")
    (ros::sleep 1) ;; wait for 1 sec to activate goal status...
    (assert (send *ri* :go-waitp) "(send *ri* :go-waitp)")
    (assert (send *ri* :go-wait) "(send *ri* :go-wait)")
    (assert (eps-v= (send (send *ri* :worldcoords ) :worldpos) #f(0 0 0)))
    (assert (send *ri* :go-pos-unsafe-no-wait -1 1 -90) "(send *ri* :go-pos-unsafe-no-wait -1 1 -90)")
    ))

(deftest test-move-to
  (let ()
    (setq *ri* (instance pr2-interface :init))
    (assert (send *ri* :move-to (make-coords :pos #f(1000 0 0))) "(send *ri* :move-to (make-coords :pos #f(1000 0 0)))") ;; default is world and wait
    (send *ri* :move-to (make-coords :pos #f(1000 1000 0) :rpy (float-vector pi/2 0 0)))
    (assert (send *ri* :move-to (make-coords) :no-wait t) "(send *ri* :move-to (make-coords) :no-wait t)") ;; no-wait t means not wait so need to call wait
    (assert (send *ri* :move-to-wait) "(send *ri* :move-to-wait)") ;; wait move-to
    (assert (eps-v= (send (send *ri* :worldcoords ) :worldpos) #f(0 0 0)))
    ))


;; https://github.com/jsk-ros-pkg/jsk_pr2eus/pull/143
(defclass pr2-interface-wrong
  :super pr2-interface)
(defmethod pr2-interface-wrong
  (:torso-controller
   ()
   (list
	(list
	 (cons :controller-action "torso_controller/follow_joint_trajectory")
	 (cons :controller-state "torso_controller/state")
	 (cons :action-type control_msgs::FollowJointTrajectoryAction)
	 (cons :joint-names (list "torso_lift_joint-NOT-FOUND"))))))


(deftest test-wrong-controller
  (let ()
    (setq *ri* (instance pr2-interface-wrong :init))
    (send *pr2* :reset-manip-pose)
    (assert (send *ri* :angle-vector (send *pr2* :angle-vector)))
    (send *pr2* :reset-pose)
    (assert (send *ri* :angle-vector-sequence (list (send *pr2* :angle-vector))))))

;;
;; https://github.com/jsk-ros-pkg/jsk_robot/pull/849#issuecomment-334906516
;;
;; add test to check sub-angle-vector over 620
(deftest test-sub-angle-vector-1000
  (let (angle diff msg)
    ;;(setq *ri* (instance pr2-interface :init))
    (send *pr2* :reset-manip-pose)
    (send *ri* :robot :reset-manip-pose)
    (dolist (inc (list 10 -10))
      (send *ri* :robot :larm :elbow-r :joint-angle 0)
      (setq angle 0.0)
      (setq diff 0.0)
      (do ((i 0 (incf i inc)))
          ((if (> inc 0) (<= 1000 i) (>= -1000 i)))
          (send *pr2* :larm :elbow-r :joint-angle i)
          (setq diff (elt (send *ri* :sub-angle-vector (send *pr2* :angle-vector) (send *ri* :robot :angle-vector)) 5))
          (setq msg (format nil ":sub-angle-vector : original angle-vector from ~A to ~A, expected ~A ~A~%" i diff angle (eps= angle diff)))
          (warning-message 2 msg)
          (assert (eps= angle diff) msg)
          (incf angle inc)
          (if (>= angle 185.0) (setq angle -170.0))
          (if (<= angle -185.0) (setq angle 170.0))
          ))
    ))

(deftest test-angle-vector-over-640
  (let (msg)
    (send *pr2* :reset-manip-pose)
    (send *ri* :robot :reset-manip-pose)
    (dolist (angle (list 60 420 780))
      (send *pr2* :larm :elbow-r :joint-angle angle)
      (send-message *ri* robot-interface :angle-vector (send *pr2* :angle-vector) 500)
      (send *ri* :wait-interpolation)
      (setq msg
            (format nil "*ri* ~A, *pr2* ~A ~A~%"
                    (elt (send *ri* :state :potentio-vector) 5)
                    (elt (send *pr2* :angle-vector) 5)
                    (eps= (elt (send *ri* :state :potentio-vector) 5) 60.0 1.0)))
      (warning-message 2 msg)
      (assert (eps= (elt (send *ri* :state :potentio-vector) 5) 60.0 1.0) msg)
      )
    ))

(deftest test-angle-vector-under-640
  (let (msg)
    (send *pr2* :reset-manip-pose)
    (send *ri* :robot :reset-manip-pose)
    (dolist (angle (list -60 -420 -780))
      (send *pr2* :larm :elbow-r :joint-angle angle)
      (send-message *ri* robot-interface :angle-vector (send *pr2* :angle-vector) 500)
      (send *ri* :wait-interpolation)
      (setq msg
            (format nil "*ri* ~A, *pr2* ~A ~A~%"
                    (elt (send *ri* :state :potentio-vector) 5)
                    (elt (send *pr2* :angle-vector) 5)
                    (eps= (elt (send *ri* :state :potentio-vector) 5) -60.0 1.0)))
      (warning-message 2 msg)
      (assert (eps= (elt (send *ri* :state :potentio-vector) 5) -60.0 1.0) msg)
      )
    ))

;; pr2 / pr2-sensor-robot test
(deftest instantiate-pr2-sensor-robot-test
  (let (rgb-camera-pr1012 rgb-camera-pr1040)
    ;; call from function
    (pr2)
    (assert *pr2*) ;; generate *pr2*
    (assert (derivedp *pr2* pr2-sensor-robot)) ;; pr2 derived from pr2-sensor-robot
    (assert (equal (send *pr2* :name) "pr2")) ;; robot name is pr2
    (assert (equal (*pr2* . name) :pr1012)) ;; but we can know serial number
    (setq rgb-camera-1012 (send (send *pr2* :camera :kinect_head/rgb) :viewing :projection))

    (pr2 :pr1040)
    (assert *pr2*) ;; generated *pr2*
    (assert (derivedp *pr2* pr2-sensor-robot)) ;; pr2 derived from pr2-sensor-robot
    (assert (equal (send *pr2* :name) "pr2")) ;; robot name is pr2
    (assert (equal (*pr2* . name) :pr1040)) ;; but we can know serial number
    (setq rgb-camera-1040 (send (send *pr2* :camera :kinect_head/rgb) :viewing :projection))
    (defun m= (m1 m2) (v= (array-entity m1) (array-entity m2)))
    (when (m= rgb-camera-1012 rgb-camera-1040)
      (warning-message 1 "each robot should have different camera param~%~A~%~A~%"
                       rgb-camera-1040 rgb-camera-1040))

    ;; use instance
    (setq *pr2* (instance pr2-robot :init))
    (assert *pr2*) ;; generate *pr2*
    (assert (derivedp *pr2* pr2-robot)) ;; pr2 derived from pr2-sensor-robot
    (assert (equal (send *pr2* :name) "pr2")) ;; robot name is pr2
    (assert (null (assoc 'name (send *pr2* :slots)))) ;; but it does not have slot 'name

    (setq *pr2* (instance pr2-sensor-robot :init))
    (assert *pr2*) ;; generate *pr2*
    (assert (derivedp *pr2* pr2-robot)) ;; pr2 derived from pr2-sensor-robot
    (assert (equal (send *pr2* :name) "pr2")) ;; robot name is pr2
    (assert (equal (*pr2* . name) :pr1012)) ;; but we can know serial number

    (setq *pr2* (instance pr2-sensor-robot :init :pr1012))
    (assert *pr2*) ;; generated *pr2*
    (assert (derivedp *pr2* pr2-sensor-robot)) ;; pr2 derived from pr2-sensor-robot
    (assert (equal (send *pr2* :name) "pr2")) ;; robot name is pr2
    (assert (equal (*pr2* . name) :pr1012)) ;; but we can know serial number

    (setq *pr2* (instance pr2-sensor-robot :init :pr1040))
    (assert *pr2*) ;; generated *pr2*
    (assert (derivedp *pr2* pr2-sensor-robot)) ;; pr2 derived from pr2-sensor-robot
    (assert (equal (send *pr2* :name) "pr2")) ;; robot name is pr2
    (assert (equal (*pr2* . name) :pr1040)) ;; but we can know serial number
    ))

(run-all-tests)
(exit)


