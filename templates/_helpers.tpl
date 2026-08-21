{{- define "powerdns-poweradmin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "powerdns-poweradmin.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "powerdns-poweradmin.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "powerdns-poweradmin.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | quote }}
app.kubernetes.io/name: {{ include "powerdns-poweradmin.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- range $k, $v := .Values.commonLabels }}
{{ $k }}: {{ $v | quote }}
{{- end }}
{{- end -}}

{{- define "powerdns-poweradmin.selectorLabels" -}}
app.kubernetes.io/name: {{ include "powerdns-poweradmin.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "powerdns-poweradmin.secretName" -}}
{{- if .Values.secrets.existingSecret -}}
{{- .Values.secrets.existingSecret -}}
{{- else -}}
{{- printf "%s-secrets" (include "powerdns-poweradmin.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "powerdns-poweradmin.pdnsRoleSecretName" -}}
{{- if .Values.postgresql.roles.pdns.existingSecret -}}
{{- .Values.postgresql.roles.pdns.existingSecret -}}
{{- else -}}
{{- printf "%s-pdns-db" (include "powerdns-poweradmin.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "powerdns-poweradmin.poweradminRoleSecretName" -}}
{{- if .Values.postgresql.roles.poweradmin.existingSecret -}}
{{- .Values.postgresql.roles.poweradmin.existingSecret -}}
{{- else -}}
{{- printf "%s-poweradmin-db" (include "powerdns-poweradmin.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "powerdns-poweradmin.pdnsDbPassword" -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (include "powerdns-poweradmin.pdnsRoleSecretName" .) -}}
{{- if .Values.postgresql.roles.pdns.generatedPassword -}}
{{- .Values.postgresql.roles.pdns.generatedPassword -}}
{{- else if $existing -}}
{{- index $existing.data "password" | b64dec -}}
{{- else -}}
{{- randAlphaNum 40 -}}
{{- end -}}
{{- end -}}

{{- define "powerdns-poweradmin.poweradminDbPassword" -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (include "powerdns-poweradmin.poweradminRoleSecretName" .) -}}
{{- if .Values.postgresql.roles.poweradmin.generatedPassword -}}
{{- .Values.postgresql.roles.poweradmin.generatedPassword -}}
{{- else if $existing -}}
{{- index $existing.data "password" | b64dec -}}
{{- else -}}
{{- randAlphaNum 40 -}}
{{- end -}}
{{- end -}}
