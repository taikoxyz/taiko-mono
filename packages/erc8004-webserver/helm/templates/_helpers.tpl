{{/*
Expand the name of the chart.
*/}}
{{- define "erc8004-webserver.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "erc8004-webserver.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "erc8004-webserver.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "erc8004-webserver.labels" -}}
helm.sh/chart: {{ include "erc8004-webserver.chart" . }}
{{ include "erc8004-webserver.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "erc8004-webserver.selectorLabels" -}}
app.kubernetes.io/name: {{ include "erc8004-webserver.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "erc8004-webserver.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "erc8004-webserver.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
PostgreSQL fullname
*/}}
{{- define "erc8004-webserver.postgresql.fullname" -}}
{{- printf "%s-postgresql" (include "erc8004-webserver.fullname" .) }}
{{- end }}

{{/*
Redis fullname
*/}}
{{- define "erc8004-webserver.redis.fullname" -}}
{{- printf "%s-redis" (include "erc8004-webserver.fullname" .) }}
{{- end }}

{{/*
Database URL
*/}}
{{- define "erc8004-webserver.databaseUrl" -}}
{{- if .Values.secrets.databaseUrl }}
{{- .Values.secrets.databaseUrl }}
{{- else }}
{{- printf "postgresql+asyncpg://%s:%s@%s:5432/%s" .Values.postgresql.auth.username .Values.postgresql.auth.password (include "erc8004-webserver.postgresql.fullname" .) .Values.postgresql.auth.database }}
{{- end }}
{{- end }}

{{/*
Redis URL
*/}}
{{- define "erc8004-webserver.redisUrl" -}}
{{- if .Values.secrets.redisUrl }}
{{- .Values.secrets.redisUrl }}
{{- else }}
{{- printf "redis://:%s@%s-master:6379" .Values.redis.auth.password (include "erc8004-webserver.redis.fullname" .) }}
{{- end }}
{{- end }}