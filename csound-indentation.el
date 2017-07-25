;;; csound-indentation.el --- A major mode for interacting and coding Csound

;; Copyright (C) 2017  Hlöðver Sigurðsson

;; Author: Hlöðver Sigurðsson <hlolli@gmail.com>
;; Version: 0.1.2
;; Package-Requires: ((emacs "25") (shut-up "0.3.2") (multi "2.0.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;  Indentation rules for csound-mode

;;; Code:


(require 'csound-util)

(defcustom csound-indentation-spaces 2
  "Set how many spaces are in indentation."
  :type 'integer
  :group 'csound-mode)

(defun csound-indentation-begin-of-expr-p ()
  (save-excursion
    (beginning-of-line 1)
    (search-forward-regexp "\\b\\(instr\\)\\b\\|\\b\\(opcode\\)\\b" (line-end-position 1) t)))

(defun csound-indentation-end-of-expr-p ()
  (save-excursion
    (beginning-of-line 1)
    (search-forward-regexp "\\b\\(endin\\)\\b\\|\\b\\(endop\\)\\b" (line-end-position 1) t)))

(defun csound-indentation-inside-instr-p ()
  (let* ((case-fold-search nil)
	 (last-instr (save-excursion (search-backward-regexp "\\(instr\\)\\b" nil t)))
	 (last-endin (save-excursion (search-backward-regexp "\\(endin\\)\\b" nil t))))
    (cond ((eq 'nil last-instr) nil)
	  ((and (numberp last-instr) (eq 'nil last-endin)) t)
	  ((< last-endin last-instr) t)
	  (t nil))))

(defun csound-indentation-inside-opcode-p ()
  (let* ((case-fold-search nil)
	 (last-opcode (save-excursion (search-backward-regexp "\\(opcode\\)\\b" nil t)))
	 (last-endop (save-excursion (search-backward-regexp "\\(endop\\)\\b" nil t))))
    (cond ((eq 'nil last-opcode) nil)
	  ((and (numberp last-opcode) (eq 'nil last-endop)) t)
	  ((< last-endop last-opcode) t)
	  (t nil))))

(defun csound-indentation-beginning-of-bool-p ()
  (save-excursion
    (beginning-of-line 1)
    (if (and (search-forward-regexp
	      "\\b\\(if\\)\\b\\|\\b\\(while\\)\\b\\|\\b\\(else\\)\\b\\|\\b\\(elseif\\)\\b\\|\\b\\(until\\)\\b"
	      (line-end-position 1) t)
	     ;; if in mix with gotos
	     ;; dont have endif therefore
	     ;; dont create logical blocks
	     (prog2
		 (beginning-of-line 1)
		 (not (search-forward-regexp "[a\\|k\\|i]?goto" (line-end-position 1) t))))
	1 0)))

(defun csound-indentation-end-of-bool-p ()
  (save-excursion
    (beginning-of-line 1)
    (if (search-forward-regexp
	 "\\b\\(endif\\)\\b\\|\\b\\(od\\)\\b\\|\\b\\(else\\)\\b\\|\\b\\(elseif\\)\\b"
	 (line-end-position 1))
	1 0)))

(defun csound-indentation-count-goto-if-mix (end-of-expr cnt)
  (if (<= end-of-expr (point))
      cnt
    (prog2
	(beginning-of-line 2)
	(csound-indentation-count-goto-if-mix
	 end-of-expr (if (and (search-forward-regexp "\\b\\(if\\)\\b" (line-end-position 1) t 1)
			      (search-forward-regexp "goto" (line-end-position 1) t 1))
			 (1+ cnt) cnt)))))

(defun csound-indentation-inside-expression-calc (expr-type)
  (let* ((beginning-of-expr (if (eq 'instr expr-type)
				(save-excursion
				  (search-backward-regexp "\\(instr\\)\\b" nil t))
			      (save-excursion
				(search-backward-regexp "\\(opcode\\)\\b" nil t))))
	 (ending-of-current-line (line-end-position))
	 (expression-to-point (buffer-substring beginning-of-expr (line-end-position 1)))
	 (count-if-statements (csound-util-recursive-count  "\\b\\(if\\)\\b" expression-to-point 0))
	 (goto-if-mix (save-excursion
			(prog2
			    (goto-char beginning-of-expr)
			    (csound-indentation-count-goto-if-mix ending-of-current-line 0))))
	 ;; (count-elseif-statements (recursive-count "\\b\\(elseif\\)\\b" (buffer-substring beginning-of-expr (line-end-position 1)) 0))
	 (count-endif-statements (csound-util-recursive-count "\\b\\(endif\\)\\b" expression-to-point 0))
	 (count-while-statements (csound-util-recursive-count "\\b\\(while\\)\\b" expression-to-point 0))
	 (count-od-statements (csound-util-recursive-count "\\b\\(od\\)\\b" expression-to-point 0))
	 (after-goto-statement (if (string-match-p "\\<\\w*:\\B" expression-to-point) 1 0))
	 (line-at-goto-statement (if (save-excursion
				       (beginning-of-line)
				       (search-forward-regexp "\\<\\w*:" (line-end-position 1) t 1))
				     1 0))
	 ;; (end-of-bool-p (csound-indentation-end-of-bool-p))
	 (begin-of-bool-p (csound-indentation-beginning-of-bool-p))
	 (tab-count (max 1 (1+ (- (+ count-if-statements
				     after-goto-statement
				     ;; count-elseif-statements
				     count-while-statements)
				  count-endif-statements
				  count-od-statements
				  begin-of-bool-p
				  line-at-goto-statement
				  goto-if-mix
				  ;;end-of-bool-p
				  )))))
    ;; (message "gotos: %d, bool-begin: %d, line-at-goto: %d, count-if: %d, mix %d" after-goto-statement begin-of-bool-p line-at-goto-statement count-if-statements goto-if-mix)
    ;; (message "tab: %d begin-bool: %d " tab-count begin-of-bool-p)
    ;; (when (and (eq 't end-of-bool-p) (not (eq 't begin-of-bool-p))) (indent-line-to (* csound-indentation-spaces (1- tab-count))))
    (indent-line-to (* csound-indentation-spaces tab-count))))


(defun csound-indentation-line ()
  "Indent current line."
  (let ((score-p (string-equal "sco" (file-name-extension (buffer-file-name)))))
    (cond
     (score-p (indent-line-to 0))
     ((csound-indentation-begin-of-expr-p) (indent-line-to 0))
     ((csound-indentation-end-of-expr-p) (indent-line-to 0))
     ((csound-indentation-inside-instr-p) (csound-indentation-inside-expression-calc 'instr))
     ((csound-indentation-inside-opcode-p) (csound-indentation-inside-expression-calc 'opcode))
     (t (indent-line-to 0)))))

(provide 'csound-indentation)

;;; csound-indentation.el ends here
