
;;; Esto representa la manecilla de los segundos.
(command "_insert" "Segundero" centro 1 1 0)
(setq ename_1 (entlast))
;;; Esto representa la manecilla de los minutos.
(command "_insert" "Minutero" centro 1 1 0)
(setq ename_2 (entlast))
;;; Esto representa la manecilla de las horas.
(command "_insert" "Horario" centro 1 1 0)
(setq ename_3 (entlast))

;;; Función para animar el movimiento de una manecilla del reloj
;;; Parámetros: entidad - nombre de la entidad a animar
;;;            repeticiones - número de pasos a realizar
;;;            paso_angular - ángulo en radianes para cada paso
(defun animar_manecilla (entidad repeticiones paso_angular / ed ang i)
  (repeat repeticiones
    ;;; Obtiene los datos de la entidad como una lista de asociación.
    (setq ed (entget entidad))
    ;;; Si no existe, se inicializa en 0.0.
    (setq ang (cdr (assoc 50 ed)))
    (if (null ang) (setq ang 0.0))
    ;;; Si el ángulo es negativo, lo ajusta sumándole 2*pi para mantenerlo en el rango [0, 2*pi].
    (setq ang (- ang paso_angular))
    (if (< ang 0.0) (setq ang (+ ang (* 2 pi))))
    ;;; Sustituye el nuevo ángulo en la lista de asociación de la entidad.
    (setq ed (subst (cons 50 ang) (assoc 50 ed) ed))
    ;;; Modifica la entidad en el dibujo con los nuevos datos.
    (entmod ed)
    ;;; Actualiza la entidad en pantalla para reflejar los cambios realizados.
    (entupd entidad)
    ;;; Redibuja únicamente la entidad modificada para optimizar el rendimiento.
    (redraw entidad)
    (command "_.delay" 1000)
  )
  (princ)
)

;;; Calcula el paso angular en radianes para cada segundo.
;;; El valor es pi/30, ya que hay 60 divisiones en un círculo completo (2*pi radianes).
(setq paso_segundos (/ pi 30.0))
(setq paso_minutos (/ pi 1800.0))
(setq paso_horas (/ pi 21600.0))

;;; Anima cada manecilla del reloj
(animar_manecilla ename_1 60 paso_segundos)    ; Segundero - 60 pasos
(animar_manecilla ename_2 60 paso_minutos)    ; Minutero - 60 pasos
(animar_manecilla ename_3 60 paso_horas)    ; Horario - 60 pasos