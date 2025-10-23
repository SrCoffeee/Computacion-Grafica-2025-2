;;; ------------------------------------------------------------
;;; IMPCSV_ATTEXT – VERSIÓN FINAL
;;; Divide X, Y, ROT, SX, SY entre 1000 SIEMPRE
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
  (setq i 0 n (strlen line) inQ nil tok "" out '())
  (while (< i n)
    (setq ch (substr line (+ i 1) 1))
    (cond
      ((or (= ch "'") (= ch "\""))
       (setq inQ (not inQ)))
      ((and (not inQ) (= ch ";"))
       (setq out (cons tok out) tok ""))
      (t (setq tok (strcat tok ch))))
    (setq i (1+ i)))
  (reverse (cons tok out)))

(defun _parse-num (s / txt)
  ;; Convierte string a número, reemplazando coma por punto
  ;; SIEMPRE divide entre 1000
  (setq txt (_strip-quotes (_trim s)))
  (if (= txt "") 
    0.0
    (progn
      (setq txt (vl-string-translate "," "." txt))
      (/ (atof txt) 1000.0))))  ; ← SIEMPRE divide entre 1000

(defun _parse-scale (s / txt)
  ;; Para escalas: divide entre 1000, pero si es 0 devuelve 1.0
  (setq txt (_strip-quotes (_trim s)))
  (if (= txt "") 
    1.0
    (progn
      (setq txt (vl-string-translate "," "." txt))
      (setq txt (/ (atof txt) 1000.0))
      (if (= txt 0.0) 1.0 txt))))  ; Si da 0, usar 1.0

(defun _rot-to-deg (v)
  ;; Rotación ya viene dividida entre 1000
  ;; Si es pequeño (<10), podría ser radianes
  (if (<= (abs v) 10.0)
    (* 180.0 (/ v pi))
    v))

(defun _ensure-layer (lay / doc)
  (if (and lay (/= lay ""))
    (progn
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
      (if (not (tblsearch "LAYER" lay))
        (vla-Add (vla-get-Layers doc) lay))
      lay)))

(defun _insert-block (name pt sx sy rotDeg lay attrs rutaBloques / path e obj arr a tag fullpath)
  (_ensure-layer lay)
  
  (if (not (tblsearch "BLOCK" name))
    (progn
      (if rutaBloques
        (progn
          (setq fullpath (strcat rutaBloques name ".dwg"))
          
          (if (findfile fullpath)
            (progn
              (command "_.INSERT" fullpath pt sx sy rotDeg)
              (while (> (getvar "CMDACTIVE") 0)
                (command ""))
              (setq e (entlast)))
            (progn
              (prompt (strcat "\n    ⚠ No encontrado: " name ".dwg"))
              (setq path (getfiled (strcat "Selecciona " name ".dwg:") rutaBloques "dwg" 16))
              (if path
                (progn
                  (command "_.INSERT" path pt sx sy rotDeg)
                  (while (> (getvar "CMDACTIVE") 0)
                    (command ""))
                  (setq e (entlast)))
                (progn
                  (prompt "\n    ✗ Omitido.")
                  (setq e nil))))))
        (progn
          (setq path (getfiled (strcat "Selecciona " name ".dwg:") "" "dwg" 16))
          (if path
            (progn
              (command "_.INSERT" path pt sx sy rotDeg)
              (while (> (getvar "CMDACTIVE") 0)
                (command ""))
              (setq e (entlast)))
            (progn
              (prompt "\n    ✗ Omitido.")
              (setq e nil))))))
    (progn
      (command "_.INSERT" name pt sx sy rotDeg)
      (while (> (getvar "CMDACTIVE") 0)
        (command ""))
      (setq e (entlast))))
  
  (if (and e lay) 
    (entmod (subst (cons 8 lay) (assoc 8 (entget e)) (entget e))))
  
  (if e
    (progn
      (setq obj (vlax-ename->vla-object e))
      (if (= (vla-get-HasAttributes obj) :vlax-true)
        (progn
          (setq arr (vlax-variant-value (vla-GetAttributes obj)))
          (foreach a (vlax-safearray->list arr)
            (setq tag (strcase (vla-get-TagString a)))
            (if (assoc tag attrs)
              (vla-put-TextString a (cdr (assoc tag attrs)))))))))
  e)

;; ---------- comando principal ----------
(defun c:IMPCSV_ATTEXT (/ path f line hdr parts name lay nom col mar mod x y rot sx sy attrs rotDeg
                          count rutaBloques archivoTemp)
  
  (prompt "\n═══════════════════════════════════════════════")
  (prompt "\n  IMPORTAR CSV CON BLOQUES")
  (prompt "\n  (Divide X,Y,ROT,SX,SY entre 1000)")
  (prompt "\n═══════════════════════════════════════════════")
  (prompt "\n\nPaso 1: Carpeta de bloques DWG")
  
  (setq archivoTemp (getfiled "Abre UN archivo .dwg de la carpeta" "" "dwg" 16))
  
  (if archivoTemp
    (progn
      (setq rutaBloques (vl-filename-directory archivoTemp))
      (setq rutaBloques (strcat rutaBloques "\\"))
      (prompt (strcat "\n✓ Carpeta: " rutaBloques)))
    (progn
      (prompt "\n⚠ Sin carpeta especificada.")
      (setq rutaBloques nil)))
  
  (prompt "\n\nPaso 2: Selecciona el CSV")
  (setq path (getfiled "CSV a importar" "" "csv;txt" 0))
  (if (not path) 
    (progn 
      (prompt "\nCancelado.") 
      (exit)))
  
  (setq f (open path "r"))
  (if (not f) 
    (progn 
      (prompt "\nError al abrir archivo.") 
      (exit)))

  (setq count 0)
  
  (prompt "\n\n═══════════════════════════════════════════════")
  (prompt "\n  IMPORTANDO...")
  (prompt "\n═══════════════════════════════════════════════\n")
  
  (setq hdr (read-line f))

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
              x    (_parse-num (nth 6 parts))      ; ← Divide entre 1000
              y    (_parse-num (nth 7 parts))      ; ← Divide entre 1000
              rot  (_parse-num (nth 8 parts))      ; ← Divide entre 1000
              sx   (_parse-scale (nth 9 parts))    ; ← Divide entre 1000
              sy   (_parse-scale (nth 10 parts))   ; ← Divide entre 1000
              attrs (list (cons "NOMBRE" nom)
                          (cons "COLOR"  col)
                          (cons "MARCA"  mar)
                          (cons "MODELO" mod))
              rotDeg (_rot-to-deg rot))
        
        (setq count (1+ count))
        (prompt (strcat "\n  " (itoa count) ". " name 
                       " → (" (rtos x 2 2) ", " (rtos y 2 2) ")"
                       " S=" (rtos sx 2 3) "×" (rtos sy 2 3)
                       " R=" (rtos rotDeg 2 1) "°"))
        
        (_insert-block name (list x y 0.0) sx sy rotDeg lay attrs rutaBloques))
      (prompt (strcat "\n  ⚠ Omitida: " (itoa (length parts)) " columnas"))))
  
  (close f)
  
  (prompt "\n\n  Ajustando vista...")
  (command "_.ZOOM" "E")
  
  (prompt "\n═══════════════════════════════════════════════")
  (princ (strcat "\n  ✓ COMPLETO: " (itoa count) " bloques"))
  (prompt "\n═══════════════════════════════════════════════\n")
  (princ))

(prompt "\n═══════════════════════════════════════════════")
(prompt "\n  ✓ IMPCSV_ATTEXT cargado")
(prompt "\n  Divide X,Y,ROT,SX,SY entre 1000 automáticamente")
(prompt "\n  Comando: IMPCSV_ATTEXT")
(prompt "\n═══════════════════════════════════════════════\n")
(princ)
