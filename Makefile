.PHONY: clean remote-load

INSTPREFIX=
VARIANT=targeted
TYPE=apps
VERSION=99.999
PROG=katello
PROGLONG=Katello
TMPDIR=${PROG}-local-tmp

ifndef DISTRO
$(error Set the DISTRO variable e.g. rhel7 or fedora21)
endif

all: policy all-data

policy: \
	${PROG}.pp.bz2

all-data: man-pages

man-pages: \
	${PROG}-selinux-enable.8 \
	${PROG}-selinux-disable.8 \
	${PROG}-selinux-relabel.8

${PROG}-selinux-enable.8: common/selinux-enable.pod.in.sh
	bash $< "${PROG}" "Foreman" | \
		pod2man --name="${@:.8=}" -c "${PROGLONG}" --section=8 --release=${VERSION} > $@

${PROG}-selinux-disable.8: common/selinux-disable.pod.in.sh
	bash $< "${PROG}" "Foreman" | \
		pod2man --name="${@:.8=}" -c "${PROGLONG}" --section=8 --release=${VERSION} > $@

${PROG}-selinux-relabel.8: common/selinux-relabel.pod.in.sh
	bash $< "${PROG}" "Foreman" | \
		pod2man --name="${@:.8=}" -c "${PROGLONG}" --section=8 --release=${VERSION} > $@

%.pp: %.te
	-mkdir ${TMPDIR} || rm -rf ${TMPDIR}/*
	cp $< ${<:.te=.fc} $< ${<:.te=.if} ${TMPDIR}/
	sed -i 's/@@VERSION@@/${VERSION}/' ${TMPDIR}/*.te
	make -C ${TMPDIR} -f /usr/share/selinux/devel/Makefile NAME=${VARIANT} DISTRO=$(DISTRO)
	mv ${TMPDIR}/$@ .

%.pp.bz2: %.pp
	bzip2 -c9 ${@:.bz2=} > $@

install: install-policy \
	install-data

install-policy: policy consolidate-installation
	install -d ${INSTPREFIX}/usr/share/selinux/${VARIANT}
	install -p -m 644 *.pp.bz2 ${INSTPREFIX}/usr/share/selinux/${VARIANT}/

install-data: all-data install-interfaces install-scripts install-manpages

install-interfaces:
	install -d ${INSTPREFIX}/usr/share/selinux/devel/include/${TYPE}
	install -p -m 644 *.if ${INSTPREFIX}/usr/share/selinux/devel/include/${TYPE}/

install-scripts:
	install -d ${INSTPREFIX}/usr/sbin
	install -p -m 755 *-enable *-disable *-relabel ${INSTPREFIX}/usr/sbin/

install-manpages:
	install -d -m 0755 ${INSTPREFIX}/usr/share/man/man8
	install -m 0644 *.8 ${INSTPREFIX}/usr/share/man/man8/

consolidate-installation:
	hardlink -c ${INSTPREFIX}/usr/share/selinux/${VARIANT}/

remote-load:
ifdef HOST
	-rsync -qrav . -e ssh --exclude .git ${HOST}:${TMPDIR}/
	ssh ${HOST} 'cd ${TMPDIR} && sed -i s/@@VERSION@@/${VERSION}/ *.te && make -f /usr/share/selinux/devel/Makefile load DISTRO=${DISTRO}'
else
	$(error You need to define your remote ssh hostname as HOST)
endif

clean:
	rm -rf *.pp *.pp.bz2 tmp/ local-tmp/ *.8 ${PROG}-*-selinux-enable ${PROG}-*-selinux-disable
