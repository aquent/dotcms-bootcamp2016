package com.aquent;

import com.dotcms.repackage.org.osgi.framework.BundleContext;
import com.dotcms.rest.config.RestServiceUtil;
import com.dotmarketing.osgi.GenericBundleActivator;

/**
 * Activates the plugin.
 *
 * @author cfalzone
 */
public class Activator extends GenericBundleActivator {

    /**
     * Starts the plugin.
     *
     * @param ctx The BunbleContext
     * @throws Exception from initializeServices
     */
    @Override
    public void start(BundleContext ctx) throws Exception {
        initializeServices(ctx);

        publishBundleServices(ctx);

        // Add rest services
        RestServiceUtil.addResource(DeleteFileResource.class);
    }

    /**
     * Stops the plugin.
     *
     * @param ctx The bundle Context
     * @throws Exception from unregisterServices
     */
    @Override
    public void stop(BundleContext ctx) throws Exception {
        RestServiceUtil.removeResource(DeleteFileResource.class);

        unpublishBundleServices();

        unregisterServices(ctx);
    }
}
