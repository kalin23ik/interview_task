{{- define "internal-service.name" -}}
envapp
{{- end }}

{{- define "internal-service.fullname" -}}
{{ .Release.Name }}
{{- end }}
