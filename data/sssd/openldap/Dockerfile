ARG tag
FROM $tag
ARG pkgs
ARG maint_test_repo
RUN export MAINT_TEST_REPO=$maint_test_repo
ENV ADDITIONAL_MODULES sle-module-legacy
RUN for r in ${MAINT_TEST_REPO//,/ }; do zypper ar $r; done
RUN zypper --gpg-auto-import-keys ref -s
RUN zypper install -y $pkgs
COPY --chown=ldap:ldap ldapserver.* slapd.conf /etc/openldap/
COPY user.ldif /tmp/user.ldif
RUN echo "root:test" | chpasswd
VOLUME ["/run"]
RUN slapadd -b dc=sssdtest,dc=com -l /tmp/user.ldif
RUN chown -R ldap:ldap /var/lib/ldap
CMD /usr/lib/openldap/start && bash 
