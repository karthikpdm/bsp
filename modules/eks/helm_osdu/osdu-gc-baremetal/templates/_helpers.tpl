{{/*
 Create the suffix for search/indexer users
 */}}

{{- define "nameSuffix" -}}
{{- if not .Values.conf.nameSuffix -}}
  {{- $_ := set $.Values.conf "nameSuffix" (randAlphaNum 6 | lower ) -}}
{{- end -}}
{{ $.Values.conf.nameSuffix }}
{{- end -}}
