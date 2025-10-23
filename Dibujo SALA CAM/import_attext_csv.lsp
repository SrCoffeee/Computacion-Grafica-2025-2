;;; ------------------------------------------------------------
;;; 1 BLOCK_NAME, 2 LAYER, 3 NOMBRE, 4 COLOR, 5 MARCA, 6 MODELO,
;;; 7 X, 8 Y, 9 ROT, 10 SX, 11 SY
;;; ------------------------------------------------------------
(vl-load-com)

;; ---------- utilidades ----------
(defun _trim (s) (vl-string-trim " \t\r\n" s))
(defun _strip-quotes (s)
  (if (and s (> (strlen s) 1)
           (member (substr s 1 1) '("'" "\""))
           (= (substr s (strlen s) 1) (substr s 1 1)))
    (substr s 2 (- (strlen s) 2))
    s))

(defun _csv-split-single (line / i n ch inQ tok out)
  ;; separa por coma respetando comillas simples
  (setq i 0 n (strlen line) inQ nil tok "" out '())
  (while (< i n)
    (setq ch (substr line (+ i 1) 1))
    (cond
      ((= ch "'")
       (setq inQ (not inQ)))
      ((and (not inQ) (= ch ","))     ; separador
       (setq out (cons tok out) tok ""))
      (t (setq tok (strcat tok ch))))
    (setq i (1+ i)))
  (reverse (cons tok out)))

(defun _num-guess (s / t v)
  (setq t (_strip-quotes (_trim s)))
  (if (= t "") 0.0
    (progn
      ;; si hay punto/ coma decimal, usa atof; si no, puede venir escalado x1000
      (if (or (wcmatch t "*.*") (wcmatch t "*,*"))
        (setq v (atof (vl-string-translate "," "." t)))
        (setq v (/ (atof t) 1000.0))) ; típico N..003 => divide entre 1000
      v)))

(defun _rot-to-deg (v / val)
  ;; acepta radianes (~<=10), grados (<=3600), o grados*1000 (>>360)
  (setq val v)
  (cond
    ((> val 3600.0) (setq val (/ val 1000.0))) ; 2700000 -> 2700
  )
  (if (<= val 10.0)
    (* 180.0 (/ val pi)) ; eran radianes
    val)                 ; ya está en grados
)

(defun _ensure-layer (lay / doc)
  (if (and lay (/= lay ""))
    (progn
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (if (not (tblsearch "LAYER" lay))
        (vla-Add (vla-get-Layers doc) lay))
      lay)))

(defun _insert-block (name pt sx sy rotDeg lay attrs / oldAttdia oldAttreq path e obj arr a tag)
  (_ensure-layer lay)
  ;; insertar (si no existe, pedir DWG)
  (if (not (tblsearch "BLOCK" name))
    (progn
      (setq path (getfiled (strcat "No existe \"" name "\". Selecciona su DWG:") "" "dwg" 16))
      (if (not path) (exit))
      (command "_.-INSERT" path pt sx sy rotDeg)
      (setq e (entlast)))
    (progn
      (setq oldAttdia (getvar "ATTDIA") oldAttreq (getvar "ATTREQ"))
      (setvar "ATTDIA" 0) (setvar "ATTREQ" 0)
      (command "_.-INSERT" name pt sx sy rotDeg)
      (setq e (entlast))
      (setvar "ATTDIA" oldAttdia) (setvar "ATTREQ" oldAttreq)))
  ;; capa
  (if (and e lay) (entmod (subst (cons 8 lay) (assoc 8 (entget e)) (entget e))))
  ;; atributos
  (setq obj (vlax-ename->vla-object e))
  (if (= (vla-get-HasAttributes obj) :vlax-true)
    (progn
      (setq arr (vlax-variant-value (vla-GetAttributes obj)))
      (foreach a (vlax-safearray->list arr)
        (setq tag (strcase (vla-get-TagString a)))
        (if (assoc tag attrs)
          (vla-put-TextString a (cdr (assoc tag attrs)))))))
  e)

;; ---------- comando principal ----------
(defun c:IMPCSV_ATTEXT (/ path f line hdr parts name lay nom col mar mod x y rot sx sy attrs rotDeg)
  (setq path (getfiled "Selecciona el CSV (desde ATTEXT)" "" "csv;txt" 0))
  (if (not path) (progn (prompt "\nCancelado.") (exit)))
  (setq f (open path "r"))
  (if (not f) (progn (prompt "\nNo pude abrir el archivo.") (exit)))

  ;; leer encabezado
  (setq hdr (read-line f))

  ;; procesar filas
  (while (setq line (read-line f))
    (setq parts (_csv-split-single line))
    (if (>= (length parts) 11)
      (progn
        (setq name (_strip-quotes (nth 0 parts))
              lay  (_strip-quotes (nth 1 parts))
              nom  (_strip-quotes (nth 2 parts))
              col  (_strip-quotes (nth 3 parts))
              mar  (_strip-quotes (nth 4 parts))
              mod  (_strip-quotes (nth 5 parts))
              x    (_num-guess (nth 6 parts))
              y    (_num-guess (nth 7 parts))
              rot  (_num-guess (nth 8 parts))
              sx   (_num-guess (nth 9 parts))
              sy   (_num-guess (nth 10 parts))
              attrs (list (cons "NOMBRE" nom)
                          (cons "COLOR"  col)
                          (cons "MARCA"  mar)
                          (cons "MODELO" mod))
              rotDeg (_rot-to-deg rot))
        (_insert-block name (list x y 0.0) sx sy rotDeg lay attrs))))
  (close f)
  (princ "\nImportación completa (IMPCSV_ATTEXT).")
  (princ))
