Summary: Bloonix Core Package
Name: bloonix-core
Version: 0.40
Release: 1%{dist}
License: Commercial
Group: Utilities/System
Distribution: RHEL and CentOS

Packager: Jonny Schulz <js@bloonix.de>
Vendor: Bloonix

BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

Source0: http://download.bloonix.de/sources/%{name}-%{version}.tar.gz
Requires: ca-certificates
Requires: openssl
Requires: perl-JSON-XS
Requires: perl(Data::Dumper)
Requires: perl(HTTP::Tiny) >= 0.022
Requires: perl(IO::Select)
Requires: perl(IO::Socket)
Requires: perl(IO::Socket::INET6)
Requires: perl(IO::Socket::SSL) >= 1.77
Requires: perl(IO::Uncompress::Gunzip)
Requires: perl(IPC::Open3)
Requires: perl(JSON)
Requires: perl(Log::Handler) >= 0.84
Requires: perl(Net::DNS::Resolver)
Requires: perl(Net::SNMP)
Requires: perl(NetAddr::IP)
Requires: perl(Params::Validate)
Requires: perl(Socket6)
Requires: perl(Term::ReadKey)
Requires: perl(Time::HiRes)
Requires: perl(Time::ParseDate)
AutoReqProv: no

%description
bloonix-core - Core modules for the Bloonix application.

%prep
%setup -q -n %{name}-%{version}

%build
%{__perl} Build.PL installdirs=vendor
%{__perl} Build

%install
%{__perl} Build install destdir=%{buildroot} create_packlist=0
find %{buildroot} -name .packlist -exec %{__rm} {} \;
find %{buildroot} -type f -name .packlist -exec rm -f {} ';'
find %{buildroot} -type f -name '*.bs' -a -size 0 -exec rm -f {} ';'
%{_fixperms} %{buildroot}/*

%pre
getent group bloonix >/dev/null || /usr/sbin/groupadd bloonix
getent passwd bloonix >/dev/null || /usr/sbin/useradd \
    bloonix -g bloonix -s /sbin/nologin -d /var/run/bloonix -r

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc ChangeLog INSTALL LICENSE
%{perl_vendorlib}/*
%{_mandir}/man3/*

%changelog
* Wed Sep 21 2016 Jonny Schulz <js@bloonix.de> - 0.40-1
- Improved error message if the creation of a unix socket fails.
* Wed Aug 24 2016 Jonny Schulz <js@bloonix.de> - 0.39-1
- Fixed server-status output.
* Sun Apr 24 2016 Jonny Schulz <js@bloonix.de> - 0.38-1
- Decreased the connect timeout by 5s.
* Sat Apr 09 2016 Jonny Schulz <js@bloonix.de> - 0.37-1
- Fixed further Timeperiod bugs.
* Tue Apr 05 2016 Jonny Schulz <js@bloonix.de> - 0.36-1
- Fixed lots of Timeperiod bugs.
* Tue Mar 29 2016 Jonny Schulz <js@bloonix.de> - 0.35-1
- Extra release because the gpg key of bloonix is updated.
* Sun Jan 31 2016 Jonny Schulz <js@bloonix.de> - 0.34-1
- Fixed slot size in Bloonix::IPC::SharedFile.
* Mon Jan 18 2016 Jonny Schulz <js@bloonix.de> - 0.33-1
- Improved logging in Bloonix::IO::SIPC.
* Fri Nov 27 2015 Jonny Schulz <js@bloonix.de> - 0.32-1
- Fix IPv4 and IPv6 parser.
* Thu Nov 26 2015 Jonny Schulz <js@bloonix.de> - 0.31-1
- Implemented feature "factor" in Bloonix::Plugin.
* Wed Nov 25 2015 Jonny Schulz <js@bloonix.de> - 0.30-1
- Fixed field length for PIDs in SharedFile.pm.
* Sun Nov 22 2015 Jonny Schulz <js@bloonix.de> - 0.29-1
- Fixed dependency: Net::DNS
* Mon Nov 16 2015 Jonny Schulz <js@bloonix.de> - 0.28-1
- New module Bloonix::NetAddr.
- Moved Bloonix::Validator to the core package and renamed it to
  Bloonix::Validate.
* Fri Sep 18 2015 Jonny Schulz <js@bloonix.de> - 0.27-1
- Fixed: skip empty objects to prevent json decode errors.
* Mon Sep 14 2015 Jonny Schulz <js@bloonix.de> - 0.26-1
- Did some performance improvements to Dispatcher.pm.
- The default value for parameter force_ipv4 is now "auto", what mean
  that ipv4 in only forced if the socket is not a listen socket.
- Added method set_tag to Bloonix::Plugin.
* Tue Aug 18 2015 Jonny Schulz <js@bloonix.de> - 0.25-1
- Moved the creation of user bloonix into the core package.
* Sun Aug 16 2015 Jonny Schulz <js@bloonix.de> - 0.24-1
- Decreased the sleep time of ProcManager to check the
  status of children. With this change the ProcManager can
  fork new children faster if the children are all in use.
* Thu Aug 06 2015 Jonny Schulz <js@bloonix.de> - 0.23-1
- Bloonix::Accessors: Renamed mk_arrays to mk_array_accessor
  and mk_hashs to mk_hash_accessor.
- Bloonix::Accessors: Improved mk_hash_accessor.
* Mon Jun 22 2015 Jonny Schulz <js@bloonix.de> - 0.22-1
- Set a default value for bloonix_host_id and bloonix_service_id
  in Bloonix::Plugin.
* Sat Jun 20 2015 Jonny Schulz <js@bloonix.de> - 0.21-1
- Implemented feature start_servers in ProcManager.pm.
* Tue Jun 16 2015 Jonny Schulz <js@bloonix.de> - 0.20-1
- Kicked DESTROY from Bloonix::IO::SIPC.
- Fixed path detection in Bloonix::Config for Windows systems.
- Bloonix::Plugin now passes the options --bloonix-host-id and
  --bloonix-service-id to each check.
* Wed Apr 22 2015 Jonny Schulz <js@bloonix.de> - 0.19-1
- Bloonix::Plugin: Improved parsing of multiple parameters and now
  an error is thrown if invalid characters are used.
* Thu Apr 16 2015 Jonny Schulz <js@bloonix.de> - 0.18-1
- Added parameter ssl_verifycn_name and ssl_verifycn_name
  to Bloonix::IO::SIPC.
* Mon Apr 06 2015 Jonny Schulz <js@bloonix.de> - 0.17-1
- Fixed snmp options in Bloonix::Plugin.
* Sat Mar 21 2015 Jonny Schulz <js@bloonix.de> - 0.16-1
- Added new core modules.
- Bug fixed in Dispatcher.pm with finished objects.
* Mon Mar 09 2015 Jonny Schulz <js@bloonix.de> - 0.15-1
- Added default parameter --suggest-options to Bloonix::Plugin
  for auto discovery.
- Bloonix::SwtichUser to switch the user and group very simple.
* Tue Jan 13 2015 Jonny Schulz <js@bloonix.de> - 0.14-1
- New option "do_not_exit" for function get_ip_by_hostname()
  in Plugin.pm.
* Fri Jan 09 2015 Jonny Schulz <js@bloonix.de> - 0.13-1
- Removing all whitepaces of each line in configuration files.
- Plugin option value is renamed to value_desc.
- Make it possible to overwrite plugin defaults.
* Tue Dec 23 2014 Jonny Schulz <js@bloonix.de> - 0.12-1
- Fixed forwarding objects of reaped children.
* Wed Dec 17 2014 Jonny Schulz <js@bloonix.de> - 0.11-1
- Implemented easy accessors for arrays and hashes.
- Allowing negative values for thresholds.
* Sat Dec 13 2014 Jonny Schulz <js@bloonix.de> - 0.10-1
- Forced version of HTTP::Tiny at least to 0.022.
- Forced version of IO::Socket::SSL at least to 1.77.
- Forced version of Log::Handler at least to 0.84.
* Thu Dec 11 2014 Jonny Schulz <js@bloonix.de> - 0.9-1
- Improved the job distrubutor of bloonix.
* Tue Dec 02 2014 Jonny Schulz <js@bloonix.de> - 0.8-1
- Thresholds are now validated if they are numeric or not.
* Sat Nov 15 2014 Jonny Schulz <js@bloonix.de> - 0.7-1
- Added option debug to Bloonix::Plugin::execute.
- The return value of Bloonix::Plugin::execute can
  now be a scalar or list of scalars.
* Mon Nov 03 2014 Jonny Schulz <js@bloonix.de> - 0.6-1
- Updated the license information.
* Sat Oct 25 2014 Jonny Schulz <js@bloonix.de> - 0.5-1
- It's not possible to redirect stdout and stderr
  to a file instead to /dev/null.
* Fri Oct 24 2014 Jonny Schulz <js@bloonix.de> - 0.4-1
- Increased the version of Log::Handler.
* Thu Oct 16 2014 Jonny Schulz <js@bloonix.de> - 0.3-1
- Added SIG PIPE handling.
* Wed Oct 15 2014 Jonny Schulz <js@bloonix.de> - 0.2-1
- Updated the dependencies for IO::Socket::SSL,
  Log::Handler and Socket6.
* Mon Aug 25 2014 Jonny Schulz <js@bloonix.de> - 0.1-1
- Initial release.
