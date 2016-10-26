package com.aquent;

import javax.servlet.http.HttpServletRequest;

import com.dotcms.repackage.javax.ws.rs.GET;
import com.dotcms.repackage.javax.ws.rs.POST;
import com.dotcms.repackage.javax.ws.rs.PUT;
import com.dotcms.repackage.javax.ws.rs.Path;
import com.dotcms.repackage.javax.ws.rs.PathParam;
import com.dotcms.repackage.javax.ws.rs.Produces;
import com.dotcms.repackage.javax.ws.rs.core.CacheControl;
import com.dotcms.repackage.javax.ws.rs.core.Context;
import com.dotcms.repackage.javax.ws.rs.core.MediaType;
import com.dotcms.repackage.javax.ws.rs.core.Response;
import com.dotcms.repackage.javax.ws.rs.core.Response.ResponseBuilder;
import com.dotcms.rest.InitDataObject;
import com.dotcms.rest.WebResource;
import com.dotmarketing.business.APILocator;
import com.dotmarketing.exception.DotDataException;
import com.dotmarketing.exception.DotSecurityException;
import com.dotmarketing.portlets.contentlet.business.ContentletAPI;
import com.dotmarketing.portlets.contentlet.business.DotContentletStateException;
import com.dotmarketing.portlets.contentlet.model.Contentlet;
import com.dotmarketing.util.Logger;
import com.liferay.portal.model.User;

/**
 * This is a jersey rest api used for deleting files.
 *
 * @author cfalzone
 *
 */

@Path("/deleteFileResource")
public class DeleteFileResource extends WebResource {
    private ContentletAPI conAPI = APILocator.getContentletAPI();
    private static long lang = APILocator.getLanguageAPI().getDefaultLanguage().getId();

    /**
     * Handles PUT requests for delete-id.
     * @param request - The request object
     * @param identifier - The identifier to delete
     * @return Jersy Response
     * @throws DotContentletStateException from delete
     * @throws DotDataException from delete
     * @throws DotSecurityException from delete
     */
    @PUT
    @Path("/by-id/{identifier}")
    @Produces(MediaType.TEXT_PLAIN)
    public Response deletePut(@Context HttpServletRequest request, @PathParam("identifier") String identifier)
                    throws DotContentletStateException, DotDataException, DotSecurityException {
        return delete(request, identifier);
    }

    /**
     * Handles POST requests for delete-id.
     * @param request - The request object
     * @param identifier - The identifier to delete
     * @return Jersy Response
     * @throws DotContentletStateException from delete
     * @throws DotDataException from delete
     * @throws DotSecurityException from delete
     */
    @POST
    @Path("/by-id/{identifier}")
    @Produces(MediaType.TEXT_PLAIN)
    public Response deletePost(@Context HttpServletRequest request, @PathParam("identifier") String identifier)
                    throws DotContentletStateException, DotDataException, DotSecurityException {
        return delete(request, identifier);
    }

    /**
     * Handles GET requests for delete-id.
     * @param request - The request object
     * @param identifier - The identifier to delete
     * @return Jersy Response
     * @throws DotContentletStateException from delete
     * @throws DotDataException from delete
     * @throws DotSecurityException from delete
     */
    @GET
    @Path("/by-id/{identifier}")
    @Produces(MediaType.TEXT_PLAIN)
    public Response deleteGett(@Context HttpServletRequest request, @PathParam("identifier") String identifier)
                    throws DotContentletStateException, DotDataException, DotSecurityException {
        return delete(request, identifier);
    }

    /**
     * Deletes a contentlet by identifier.
     * @param request - The request object
     * @param identifier - The identifier to delete
     * @return The Jersey Repsonse
     * @throws DotContentletStateException from conAPI
     * @throws DotDataException from conAPI
     * @throws DotSecurityException from conAPI
     */
    private Response delete(HttpServletRequest request, String identifier)
                    throws DotContentletStateException, DotDataException, DotSecurityException {
        InitDataObject auth = init(null, true, request, true);
        User user = auth.getUser();

        if (user != null) {
            Logger.info(this, "User:" + user.getEmailAddress() + " deleting content with identifier:" + identifier);

            // First Find the contentlet
            Contentlet con = conAPI.findContentletByIdentifier(identifier, true, lang,  user, true);
            if (con == null || con.getIdentifier() == null) {
                // Couldn't find the content
                Logger.warn(this, "Contentlet not found with identifier:" + identifier);
                CacheControl cc = new CacheControl();
                cc.setNoCache(true);
                ResponseBuilder builder = Response.ok("FAIL:NoContent", MediaType.TEXT_PLAIN);
                return builder.cacheControl(cc).build();
            }

            // unpublish
            conAPI.unpublish(con, user, true);
            // archive
            conAPI.archive(con, user, true);
            // delete
            conAPI.delete(con, user, true);

            // Return the response
            CacheControl cc = new CacheControl();
            cc.setNoCache(true);
            ResponseBuilder builder = Response.ok("SUCCESS", MediaType.TEXT_PLAIN);
            return builder.cacheControl(cc).build();
        } else {
            // No User
            Logger.warn(this, "Unauthorized user attempted to delete contentlet with identifier:" + identifier);
            CacheControl cc = new CacheControl();
            cc.setNoCache(true);
            ResponseBuilder builder = Response.ok("FAIL:NoUser", MediaType.TEXT_PLAIN);
            return builder.cacheControl(cc).build();
        }
    }
}
