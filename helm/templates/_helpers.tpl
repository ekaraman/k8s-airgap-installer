{{- define "hello-nginx.name" -}}
hello-nginx
{{- end -}}

{{- define "hello-nginx.fullname" -}}
{{ .Release.Name }}-hello-nginx
{{- end -}}

