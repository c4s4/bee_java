package test;

import java.net.URL;
import org.apache.xmlrpc.client.XmlRpcClient;
import org.apache.xmlrpc.client.XmlRpcClientConfigImpl;

public class Client {

    public static void main(String[] args)
        throws Exception {
        XmlRpcClientConfigImpl config = new XmlRpcClientConfigImpl();
        config.setServerURL(new URL("http://localhost:8000"));
        XmlRpcClient client = new XmlRpcClient();
        client.setConfig(config);
        Object[] params = new Object[]{"World"};
        System.out.println(client.execute("test.hello", params));
    }

}
