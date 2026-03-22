;;; clj-doc-browse.el --- Browse Clojure library docs from classpath JARs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Clark Communications Corporation

;; Author: Don Jackson <dcj@clark-communications.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (cider "1.0") (markdown-mode "2.5"))
;; Keywords: clojure, documentation, tools
;; URL: https://github.com/dcj/clj-doc-browse-el
;; SPDX-License-Identifier: MIT

;; This file is not part of GNU Emacs.

;; MIT License
;;
;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.

;;; Commentary:

;; Browse Markdown API documentation embedded in Clojure library JARs.
;;
;; Clojure libraries built with codox-md embed Markdown documentation as
;; classpath resources under docs/<group>/<artifact>/.  This package provides
;; Emacs commands to browse that documentation via CIDER's nREPL connection.
;;
;; Prerequisites:
;;   - A running nREPL with cider-nrepl middleware
;;   - The clj-doc-browse Clojure library on the REPL classpath
;;   - Libraries built with codox-md on the classpath
;;
;; Usage:
;;   M-x clj-doc-browse     - browse a namespace's docs (rendered Markdown)
;;   M-x clj-doc-libraries  - list all documented libraries on the classpath
;;   M-x clj-doc-search     - full-text search across all embedded docs
;;
;; In the *clj-docs* buffer:
;;   C-c C-o  - follow source link at point (opens in Emacs, even from JARs)
;;   RET      - same as C-c C-o
;;   n/p      - next/previous heading (markdown-view-mode)
;;   q        - close the buffer

;;; Code:

(require 'cider)
(require 'markdown-mode)

;;; Source link handling

(defun clj-doc-browse--extract-source-info (url)
  "Extract classpath-relative path and line from a GitHub source URL.
Returns (classpath-path . line) or nil.
E.g. \\=`.../blob/abc123/src/mdns/core.clj#L49\\=' -> (\"mdns/core.clj\" . 49)"
  (when (string-match "/blob/[^/]+/src/\\(.*\\)#L\\([0-9]+\\)$" url)
    (cons (match-string 1 url)
          (string-to-number (match-string 2 url)))))

(defun clj-doc-browse--open-source (url)
  "Open source from URL using CIDER to find on the classpath.
Works for local files and files inside JARs.  Falls back to
`browse-url' for non-source links or if the resource is not found."
  (let ((info (clj-doc-browse--extract-source-info url)))
    (if info
        (let* ((classpath-path (car info))
               (line (cdr info))
               (conn (cider-current-connection))
               (response (nrepl-sync-request:eval
                          (format "(let [r (clojure.java.io/resource \"%s\")]
                                     (when r (.toString r)))"
                                  classpath-path)
                          conn))
               (value (nrepl-dict-get response "value")))
          (if (or (null value) (string= value "nil"))
              (browse-url url)
            (let* ((resource-url (read value))
                   (buf (cider-find-file resource-url)))
              (when buf
                (pop-to-buffer buf)
                (goto-char (point-min))
                (forward-line (1- line))))))
      (browse-url url))))

(defun clj-doc-browse-follow-link-at-point ()
  "Follow the markdown link at point, opening source in Emacs."
  (interactive)
  (let ((url (markdown-link-url)))
    (if url
        (clj-doc-browse--open-source url)
      (message "No link at point"))))

;;; Keymap

(defvar clj-doc-browse-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-o") #'clj-doc-browse-follow-link-at-point)
    (define-key map (kbd "RET") #'clj-doc-browse-follow-link-at-point)
    map)
  "Keymap active in `clj-doc-browse' documentation buffers.")

;;; Commands

;;;###autoload
(defun clj-doc-browse (query)
  "Browse Clojure library documentation from classpath JARs.
Prompts for QUERY, a namespace name or qualified path.  Fetches
the Markdown documentation via CIDER and displays it in a
read-only `markdown-view-mode' buffer with source link navigation."
  (interactive "sNamespace or library: ")
  (cider-ensure-connected)
  (cider-nrepl-request:eval
   (format "(do (require 'doc.browse) (doc.browse/show \"%s\"))" query)
   (lambda (response)
     (nrepl-dbind-response response (value err)
       (if err
           (message "clj-doc-browse error: %s" err)
         (when value
           (let ((content (read value))
                 (buf (get-buffer-create "*clj-docs*")))
             (if (null content)
                 (message "No documentation found for %s" query)
               (with-current-buffer buf
                 (let ((inhibit-read-only t))
                   (erase-buffer)
                   (insert content)
                   (goto-char (point-min))
                   (if (fboundp 'markdown-view-mode)
                       (markdown-view-mode)
                     (markdown-mode)
                     (view-mode))
                   (use-local-map (make-composed-keymap
                                   clj-doc-browse-mode-map
                                   (current-local-map)))
                   (setq buffer-read-only t)))
               (pop-to-buffer buf)))))))
   "user"))

;;;###autoload
(defun clj-doc-libraries ()
  "List all documented libraries on the classpath.
Displays the result in the minibuffer."
  (interactive)
  (cider-ensure-connected)
  (cider-nrepl-request:eval
   "(do (require 'doc.browse) (mapv :name (doc.browse/libraries)))"
   (lambda (response)
     (nrepl-dbind-response response (value err)
       (if err
           (message "clj-doc-browse error: %s" err)
         (when value
           (message "Documented libraries: %s" value)))))
   "user"))

;;;###autoload
(defun clj-doc-search (query)
  "Full-text search across all classpath documentation.
Prompts for QUERY and displays matching lines in a results buffer."
  (interactive "sSearch docs: ")
  (cider-ensure-connected)
  (cider-nrepl-request:eval
   (format "(do (require 'doc.browse)
                (with-out-str
                  (doseq [{:keys [library namespace line context]}
                          (doc.browse/search \"%s\")]
                    (println (format \"%%s/%%s:%%d  %%s\" library namespace line context)))))"
           query)
   (lambda (response)
     (nrepl-dbind-response response (value err)
       (if err
           (message "clj-doc-browse error: %s" err)
         (when value
           (let ((content (read value))
                 (buf (get-buffer-create "*clj-doc-search*")))
             (with-current-buffer buf
               (let ((inhibit-read-only t))
                 (erase-buffer)
                 (insert content)
                 (goto-char (point-min))
                 (special-mode)))
             (pop-to-buffer buf))))))
   "user"))

(provide 'clj-doc-browse)

;;; clj-doc-browse.el ends here
