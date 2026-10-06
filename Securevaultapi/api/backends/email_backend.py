import ssl
import socket
import smtplib
from django.core.mail.backends.smtp import EmailBackend as SMTPBackend
from django.utils.functional import cached_property

class ForceIPv4SMTP(smtplib.SMTP):
    """SMTP class that forces IPv4 connections."""
    def _get_socket(self, host, port, timeout):
        # Resolve to IPv4 only to prevent 'Network is unreachable' with IPv6
        info = socket.getaddrinfo(host, port, socket.AF_INET, socket.SOCK_STREAM)
        err = None
        for res in info:
            af, socktype, proto, canonname, sa = res
            s = None
            try:
                s = socket.socket(af, socktype, proto)
                if self.source_address:
                    s.bind(self.source_address)
                if timeout is not socket._GLOBAL_DEFAULT_TIMEOUT:
                    s.settimeout(timeout)
                s.connect(sa)
                return s
            except OSError as e:
                err = e
                if s is not None:
                    s.close()
        if err is not None:
            raise err
        else:
            raise OSError("getaddrinfo returns an empty list")

class ForceIPv4SMTP_SSL(smtplib.SMTP_SSL):
    """SMTP_SSL class that forces IPv4 connections."""
    def _get_socket(self, host, port, timeout):
        info = socket.getaddrinfo(host, port, socket.AF_INET, socket.SOCK_STREAM)
        err = None
        for res in info:
            af, socktype, proto, canonname, sa = res
            s = None
            try:
                s = socket.socket(af, socktype, proto)
                if self.source_address:
                    s.bind(self.source_address)
                if timeout is not socket._GLOBAL_DEFAULT_TIMEOUT:
                    s.settimeout(timeout)
                s.connect(sa)
                return s
            except OSError as e:
                err = e
                if s is not None:
                    s.close()
        if err is not None:
            raise err
        else:
            raise OSError("getaddrinfo returns an empty list")

class EmailBackend(SMTPBackend):
    @property
    def connection_class(self):
        return ForceIPv4SMTP_SSL if self.use_ssl else ForceIPv4SMTP

    @cached_property
    def ssl_context(self):
        if self.ssl_certfile or self.ssl_keyfile:
            ssl_context = ssl.SSLContext(protocol=ssl.PROTOCOL_TLS_CLIENT)
            ssl_context.load_cert_chain(self.ssl_certfile, self.ssl_keyfile)
            return ssl_context
        else:
            ssl_context = ssl.create_default_context()
            ssl_context.check_hostname = False
            ssl_context.verify_mode = ssl.CERT_NONE
            return ssl_context