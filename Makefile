all: clean checkip all_domains.txt domain.crt

#MAINHOST=$(shell sudo -u zimbra -i /opt/zimbra/bin/zmhostname)
MAINHOST=$(shell ls -1t /var/lib/acme/live/ | head -n 1)
ACMEDIR=/var/lib/acme/live/$(MAINHOST)
DATETIME=$(shell date "+%Y%m%d_%H%M%S")

clean:
	rm -f all_domains.txt zimbra_chain.crt domain.crt domain.key
	
all_domains.txt:
	sudo -u zimbra -i sh -c "(/opt/zimbra/bin/zmhostname; /opt/zimbra/bin/zmprov -l GetAllDomains | xargs -i /opt/zimbra/bin/zmprov -l getDomain {} zimbraVirtualHostname | grep zimbraVirtualHostname: | cut -f2 -d: )"> $@
	sudo -u acme acmetool  want `cat all_domains.txt` 

checkip: all_domains.txt
	for ip in $$(getent hosts $$(cat all_domains.txt) | awk '{print $$1}'); do ip addr show | fgrep -q -w $$ip || awk "BEGIN {print \"FATAL: unknown ip $$ip\"; exit(1)}"; done

domain.crt: root.ca  $(ACMEDIR)/privkey $(ACMEDIR)/chain $(ACMEDIR)/cert all_domains.txt
	@echo "Using $(MAINHOST) as authorative certificate..."
	cp $(ACMEDIR)/privkey domain.key
	cp $(ACMEDIR)/cert domain.crt
	cat $(ACMEDIR)/chain root.ca  > zimbra_chain.crt
	chown zimbra domain.key domain.crt zimbra_chain.crt
	sudo -u zimbra /opt/zimbra/bin/zmcertmgr verifycrt comm domain.key domain.crt zimbra_chain.crt
	test -d backups || mkdir backups
	tar zcf backups/zimbra_ssl.$(DATETIME).tar.gz /opt/zimbra/ssl/zimbra
	sudo -u zimbra sh -c 'cat domain.key > /opt/zimbra/ssl/zimbra/commercial/commercial.key'
	sudo -u zimbra /opt/zimbra/bin/zmcertmgr deploycrt comm domain.crt zimbra_chain.crt
	#sudo -u zimbra -i /opt/zimbra/bin/zmcontrol restart || sudo -u zimbra -i /opt/zimbra/bin/zmcontrol start || sudo -u zimbra -i sh -c "sleep 2m; /opt/zimbra/bin/zmcontrol start"
	sudo -u zimbra -i /opt/zimbra/bin/ldap restart
	sudo -u zimbra -i /opt/zimbra/bin/zmproxyctl restart
	sudo -u zimbra -i /opt/zimbra/bin/zmmailboxdctl restart
	sudo -u zimbra -i /opt/zimbra/bin/zmmtactl restart
	sudo -u zimbra -i /opt/zimbra/bin/zmstatctl start

.PHONY: checkip clean all
