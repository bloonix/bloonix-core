Summary: Bloonix Core Package
Name: bloonix-core
Version: 0.6
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
Requires: perl(Data::Dumper)
Requires: perl(HTTP::Tiny)
Requires: perl(IO::Select)
Requires: perl(IO::Socket)
Requires: perl(IO::Socket::INET6)
Requires: perl(IO::Socket::SSL) >= 1.76
Requires: perl(IO::Uncompress::Gunzip)
Requires: perl(IPC::Open3)
Requires: perl(JSON)
Requires: perl(Log::Handler) >= 0.84
Requires: perl(Net::SNMP)
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

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc ChangeLog INSTALL LICENSE
%{perl_vendorlib}/*
%{_mandir}/man3/*

%changelog
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