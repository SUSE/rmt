#
# update_rmt_app_dir_permissions.sh
# This scripts adjusts the user and group permissions
# of the RMT application directory.
set -euo pipefail

IFS=" "

app_dir=$1
app_dir_ownership=$(stat -c "%U %G" $app_dir)

if [[ $app_dir_ownership == "_rmt nginx" ]]; then
  find -P $app_dir -type d | ruby -e 'dirs=readlines; dirs.each { |dir| puts("#{dir.strip} #{dir.strip.length}") }' | sort -k 2 -n | awk '/ / {print $1}' | xargs -I {} chown -h root:root {}
  find -P $app_dir -type f -user _rmt -group nginx | xargs -I {} chown -h root:root {}
fi
