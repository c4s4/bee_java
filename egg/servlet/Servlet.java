package <%= _package %>;

import java.io.*;
import javax.servlet.*;

public class <%= _main_class %>
    extends GenericServlet {

    public void service(ServletRequest request, ServletResponse response)
        throws ServletException, IOException {
	ServletOutputStream out = response.getOutputStream() ;
	out.println("<HTML><HEAD>") ;
	out.println("<TITLE>Hello World!</TITLE>") ;
	out.println("</HEAD>") ;
	out.println("<BODY>") ;
	out.println("<H3>Hello World!</H3>") ;
	out.println("</BODY></HTML>") ;
    }

}
