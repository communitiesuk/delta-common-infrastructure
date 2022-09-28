<%
  final String redirectURL = "/jasperserver/";
  response.setStatus(response.SC_MOVED_PERMANENTLY);
  response.sendRedirect(redirectURL);
%>
