#!/bin/bash
set -e

if [ "$1" = bacula-dir ]; then
	if [[ -z $DB_PORT && -n $DB_HOST && $DB_HOST != localhost && $DB_HOST != 127.0.0.1 ]]; then
		export DB_PORT=3306
	fi

	# Change config settings on bacula-dir.conf
	sed -i "s/\(Director\s*{\s*\n\s*Name\s=\s\).*$/\1$DIR_NAME/" /opt/bacula/etc/bacula-dir.conf
	sed -i "s/\(^\s*dbname\s*=\s*\).*\s*\(user\s*=\s*\).*\s*\(password\s*=\s*\).*$/\1$DB_NAME\;\ \2$DB_USER\;\ \3\"$DB_PASS\"/" /opt/bacula/etc/bacula-dir.conf
	if [[ -z $DB_HOST ]]; then
		grep -q 'DB Address' /opt/bacula/etc/bacula-dir.conf && \
			sed -i "s/\(DB\sAddress\s*=\s*\).*/\1$DB_HOST/" /opt/bacula/etc/bacula-dir.conf || \
				sed -i "s/\(^.*dbname.*$\)/\1\n  DB Address = $DB_HOST/" /opt/bacula/etc/bacula-dir.conf
	fi		
	if [[ -z $DB_PORT ]]; then
		grep -q 'DB Port' /opt/bacula/etc/bacula-dir.conf && \
			sed -i "s/\(DB\sPort\s*=\s*\).*/\1$DB_PORT/" /opt/bacula/etc/bacula-dir.conf || \
				sed -i "s/\(^.*DB\sAddress.*$\)/\1\n  DB Port = $DB_PORT/" /opt/bacula/etc/bacula-dir.conf
	fi
	# add mysql creation of db if not exists
	export db_name="$DB_NAME"
	/opt/bacula/etc/create_bacula_database mysql -u $DB_USER ${DB_PASS:+-p$DB_PASS} ${DB_HOST:+-h $DB_HOST} ${DB_PORT:+-P $DB_PORT}
	/opt/bacula/etc/make_bacula_tables mysql -u $DB_USER ${DB_PASS:+-p$DB_PASS} ${DB_HOST:+-h $DB_HOST} ${DB_PORT:+-P $DB_PORT}

	# Change message settings
	if [[ -z $ADMIN_EMAIL ]]; then
		Messages="Messages {\n"
		Messages="$Messages   Name = Standard\n"
		Messages="$Messages   mailcommand = \"/home/bacula/bin/bsmtp -h ${SMTP_HOST:-localhost}\n"
		Messages="$Messages                 -f \\\"\\(Bacula\\) %r\\\"\n"
		Messages="$Messages                 -s \\\"Bacula: %t %e of %c %l\\\" %r\"\n"
		Messages="$Messages   operatorcommand = \"/home/bacula/bin/bsmtp -h localhost\n"
		Messages="$Messages                 -f \\\"\\(Bacula\\) %r\\\"\n"
		Messages="$Messages                 -s \\\"Bacula: Intervention needed for %j\\\" %r\"\n"
		Messages="$Messages   Mail = ${ADMIN_EMAIL} = all, !skipped, !terminate\n"
		Messages="$Messages   append = \"/home/bacula/bin/log\" = all, !skipped, !terminate\n"
		Messages="$Messages   operator = ${ADMIN_EMAIL} = mount\n"
		Messages="$Messages   console = all, !skipped, !saved/\n"
		Messages="$Messages }\n"
		sed -i 's/Messages\s*{\s*Name = Standard.*!skipped$^}/$Messages/' /opt/bacula/etc/bacula-dir.conf
	fi

	exec /opt/bacula/bin/bacula-dir -d 100 -f /opt/bacula/etc/bacula-dir.conf

fi

exec "$@"
