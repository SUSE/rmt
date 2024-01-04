#
# update_rmt_app_dir_permissions.sh
# This scripts adjusts the user and group permissions
# of the RMT application directory.
set -euo pipefail

IFS=" "

app_dir=$1
app_dir_ownership=$(stat -c "%U %G" $app_dir)

if [[ $app_dir_ownership == "_rmt nginx" ]]; then
  # Sort application directory ordered by directory depth to
  # ensure secure recursive ownership change.
  find -P $app_dir -type d | ruby -e 'dirs=readlines; dirs.each { |dir| puts("#{dir.strip} #{dir.strip.length}") }' | sort -k 2 -n | awk '/ / {print $1}' | xargs -I {} chown -h root:root {}

  find -P $app_dir -type f -user _rmt -group nginx | xargs -I {} chown -h root:root {}
fi

# Change secrets encrypted and key files to nginx readable
secret_key_files=('config/secrets.yml.key' 'config/secrets.yml.enc')

for secretFile in ${secret_key_files[@]}; do
  file_path="$app_dir/$secretFile"
  if [[ -e $file_path ]]; then
    if [[ "$(stat -c "%U %G" $file_path)" == "root root" ]]; then
      chmod 0640 $file_path
      chown -h root:nginx $file_path
    fi
  fi

done
