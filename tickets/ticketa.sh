#!/bin/bash
# Author: Jy Kingston
# Email: jy.kingston@gmail.com
#
# Ticket Add - Allows for easy ticket management via the CLI

# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
#set -o nounset
# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail
# Turn on traces, useful while debugging but commented out by default
#set -o xtrace

TICKET_NUMBER="$1"
TICKET_DIRECTORY="${HOME}/support/tickets"

pprint() {
  toilet "${1}" -F border -f small -t --gay
}

create_local_ticket_directory() {
  TICKET_FP="${TICKET_DIRECTORY}/${TICKET_NUMBER}/"
  if [ ! -d "${TICKET_FP}" ]; then
    mkdir "${TICKET_FP}" && pprint "Created ${TICKET_NUMBER}"
  fi
}

# If the directory is missing a main file
# Copy our master templates in and replace vars
populate_templates() {
  if [ ! -f "${TICKET_DIRECTORY}/main.tf" ]; then
    cp "$TICKET_DIRECTORY/master/main.tf" "${TICKET_FP}/" || exit 1
    sed -i "s/TICKET_NUMBER/${TICKET_NUMBER}/g" "${TICKET_FP}/main.tf"
  fi
}

# check the local google-chrome session files for any zendesk URLS
current_ticket_urls() {
  TICKET_NUMBER=$(for SESSION in $(ls -dt "${HOME}"/.config/google-chrome/Default/Sessions/* | head -2); do
    strings "${SESSION}" | grep -E '^https?://hashicorp.zendesk.com/agent/tickets/[0-9]{5}' | grep -Pv '[0-9]{7}' | uniq | sed -e 's/.*\/agent\/tickets\///' -e 's/\/.*//'
  done | fzf --border --inline-info --tac)
  test ! -z "${TICKET_NUMBER}" || exit 1
  pprint "Ticket: ${TICKET_NUMBER}"
  create_local_ticket_directory && populate_templates
  cd "${TICKET_FP}" && open_in_pycharm && open_in_chrome
}

# List all README.md files in the TICKET_DIRECTORY for each TICKET_NUMBER
get_all_readme_files() {
  README_FILE=$(ls -d "${TICKET_DIRECTORY}"/*/README.md | fzf --border --preview="mdless {+}" --preview-window=down:50% --inline-info --tac)
  TICKET_DIRECTORY="$(dirname "${README_FILE}")"
  TICKET_NUMBER="${TICKET_DIRECTORY##*/}"
  test ! -z "${TICKET_NUMBER}" || exit 1
  pprint "Ticket: ${TICKET_NUMBER}"
  cd "${TICKET_DIRECTORY}" && open_in_pycharm && open_in_chrome
}

existing_ticket_menu() {
  TICKET_DIRECTORY=$(fdfind '^[0-9]*+$' "${TICKET_DIRECTORY}" -d1 | fzf --border --inline-info --tac | xargs)
  TICKET_NUMBER="${TICKET_DIRECTORY##*/}"
  test ! -z "${TICKET_NUMBER}" || exit 1
  pprint "Ticket: ${TICKET_NUMBER}"
  populate_templates
  cd "${TICKET_FP}" && open_in_pycharm && open_in_chrome
}

open_in_chrome() {
  echo -e "\tOpening in Chrome..."
  google-chrome "https://hashicorp.zendesk.com/agent/tickets/${TICKET_NUMBER}" >/dev/null 2>&1 &
}

open_in_pycharm() {
  echo -e "\tOpening in Pycharm..."
  BAMF_DESKTOP_FILE_HINT=/var/lib/snapd/desktop/applications/pycharm-professional_pycharm-professional.desktop /snap/bin/pycharm-professional . >/dev/null 2>&1 &
}

open_in_vscode() {
  code .
}

if [[ -z "${1}" ]]; then
  existing_ticket_menu
elif [[ "${1}" == "url" ]]; then
  current_ticket_urls
elif [[ "${1}" == "readme" ]]; then
  get_all_readme_files
fi

$SHELL
