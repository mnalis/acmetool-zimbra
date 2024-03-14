kall: clean checkip all_domains.txt domain.crt

ZBINDIR=/opt/zimbra/bin
MAINHOST=$(shell sudo -u zimbra -i $(ZBINDIR)/zmhostname)
#MAINHOST=$(shell ls -1t /var/lib/acme/live/ | head -n 1)
ACMEDIR=/var/lib/acme/live/$(MAINHOST)
DATETIME=$(shell date "+%Y%m%d_%H%M%S")

clean:
	rm -f all_domains.txt zimbra_chain.crt domain.crt domain.key

reallyclean: clean
	rm -f root.ca
	
all_domains.txt:
	sudo -u zimbra -i sh -c "($(ZBINDIR)/zmhostname; $(ZBINDIR)/zmprov -l GetAllDomains | xargs -i $(ZBINDIR)/zmprov -l getDomain {} zimbraVirtualHostname | grep zimbraVirtualHostname: | cut -f2 -d: )"> $@
	sudo -u acme acmetool  want `cat all_domains.txt` 

root.ca:
	wget -q https://letsencrypt.org/certs/isrgrootx1.pem -O $@

checkip: all_domains.txt
	for ip in $$(getent hosts $$(cat all_domains.txt) | awk '{print $$1}'); do ip addr show | fgrep -q -w $$ip || awk "BEGIN {print \"FATAL: unknown ip $$ip\"; exit(1)}"; done

domain.crt: root.ca  $(ACMEDIR)/privkey $(ACMEDIR)/chain $(ACMEDIR)/cert all_domains.txt
	@echo "Using $(MAINHOST) as authorative certificate..."
	cp $(ACMEDIR)/privkey domain.key
	cp $(ACMEDIR)/cert domain.crt
	# if chain cointains expired "DST ROOT X3", manually force alternative chain (as acmetool 0.2.1-4+b5 does not support --prefered-chain)
	# sed -ne '/^-----END CERTIFICATE-----/,$$p' $(ACMEDIR)/chain | openssl x509 -noout -issuer -nameopt sname 2>/dev/null | fgrep -q 'CN=DST Root CA X3' && (sed -ne '1,/^-----END CERTIFICATE-----/p' $(ACMEDIR)/chain; cat root.ca) > zimbra_chain.crt || cat root.ca $(ACMEDIR)/chain > zimbra_chain.crt
	cat root.ca $(ACMEDIR)/chain > zimbra_chain.crt
	chown zimbra domain.key domain.crt zimbra_chain.crt
	sudo -u zimbra $(ZBINDIR)/zmcertmgr verifycrt comm domain.key domain.crt zimbra_chain.crt
	test -d backups || mkdir backups
	tar zcf backups/zimbra_ssl.$(DATETIME).tar.gz /opt/zimbra/ssl/zimbra
	sudo -u zimbra sh -c 'cat domain.key > /opt/zimbra/ssl/zimbra/commercial/commercial.key'
	sudo -u zimbra $(ZBINDIR)/zmcertmgr deploycrt comm domain.crt zimbra_chain.crt
	#sudo -u zimbra -i $(ZBINDIR)/zmcontrol restart || sudo -u zimbra -i $(ZBINDIR)/zmcontrol start || sudo -u zimbra -i sh -c "sleep 2m; $(ZBINDIR)/zmcontrol start"
	sudo -u zimbra -i $(ZBINDIR)/ldap restart
	sudo -u zimbra -i $(ZBINDIR)/zmproxyctl restart
	sudo -u zimbra -i $(ZBINDIR)/zmmailboxdctl restart
	sudo -u zimbra -i $(ZBINDIR)/zmmtactl restart
	sudo -u zimbra -i $(ZBINDIR)/zmstatctl start

.PHONY: checkip clean reallyclean all
