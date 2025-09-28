;;; Esto representa la manecilla de los segundos.
(command "_insert" "Segundero" centro 1 1 0)
(setq ename_1 (entlast))
;;; Esto representa la manecilla de los minutos.
(command "_insert" "Minutero" centro 1 1 0)
(setq ename_2 (entlast))
;;; Esto representa la manecilla de las horas.
(command "_insert" "Horario" centro 1 1 0)
(setq ename_3 (entlast))
(defun mover_manecilla (entidad paso_angular / ed ang has50)
  (setq ed   (entget entidad))
  (setq ang  (cdr (assoc 50 ed)))           ; ángulo en radianes (puede ser nil)
  (if (null ang) (setq ang 0.0))
  (setq ang (- ang paso_angular))           ; horario => restar
  (if (< ang 0.0) (setq ang (+ ang (* 2 pi))))

  (setq has50 (assoc 50 ed))
  (setq ed (if has50
             (subst (cons 50 ang) has50 ed) ; reemplaza si existe
             (append ed (list (cons 50 ang))))) ; agrega si no existe

  (entmod ed) (entupd entidad) (redraw entidad 3)
)

;;; Función para simular el reloj real
(defun c:RELOJ (/ paso_segundos paso_minutos paso_horas contador)
  ;;; Calcula los pasos angulares
  (setq paso_segundos (/ pi 30.0)) ; 60 divisiones = pi/30
  (setq paso_minutos (/ pi 1800.0)) ; 3600 divisiones = pi/1800
  (setq paso_horas (/ pi 21600.0))   ; 43200 divisiones = pi/21600
  (setq contador 0)
  (repeat 3600
    (mover_manecilla ename_1 paso_segundos)
    (mover_manecilla ename_2 paso_minutos)
    (mover_manecilla ename_3 paso_horas)
    (setq contador (+ contador 1))
    (command "_.delay" 1000)
  )
  ;(princ)
)