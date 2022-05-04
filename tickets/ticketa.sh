#!/bin/bash
set -e

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
  CURRENT_SESSION=$(ls -d "${HOME}"/.config/google-chrome/Default/Sessions/Tabs* | head -1)
  TICKET_NUMBER=$(strings "${CURRENT_SESSION}" | grep -E '^https?://hashicorp.zendesk.com/agent/tickets/*' | uniq | fzf --border --inline-info --tac | sed -e 's/.*\/agent\/tickets\///' -e 's/\/.*//')
  test ! -z "${TICKET_NUMBER}" || exit 1
  pprint "Ticket: ${TICKET_NUMBER}"
  create_local_ticket_directory && populate_templates
  cd "${TICKET_FP}" && open_in_pycharm && open_in_chrome
}

# List all README.md files in the TICKET_DIRECTORY for each TICKET_NUMBER
get_all_readme_files() {
  for FILE in "${TICKET_DIRECTORY}"/*/README.md; do
    if [ -f "${FILE}" ]; then
      README_FILE=$(fzf --border --preview="mdless ${FILE}" --preview-window=down:50% --inline-info --tac)
      TICKET_NUMBER=$(sed 's/[^1-5]//g' "${README_FILE}")
      test ! -z "${TICKET_NUMBER}" || exit 1
      pprint "Ticket: ${TICKET_NUMBER}"
      cd "${TICKET_FP}" && open_in_pycharm && open_in_chrome
    fi
  done
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
  cd "${TICKET_FP}"
  google-chrome "https://hashicorp.zendesk.com/agent/tickets/${TICKET_NUMBER}" >/dev/null 2>&1 &
}

open_in_pycharm() {
  echo -e "\tOpening in Pycharm..."
  cd "${TICKET_FP}"
  BAMF_DESKTOP_FILE_HINT=/var/lib/snapd/desktop/applications/pycharm-professional_pycharm-professional.desktop /snap/bin/pycharm-professional . >/dev/null 2>&1 &
  $SHELL
}

open_in_vscode() {
  code .
}

if [[ -z "$1" ]]; then
  existing_ticket_menu
elif [[ "${1}" == "url" ]]; then
  current_ticket_urls
elif [[ "${1}" == "readme" ]]; then
  get_all_readme_files
fi
