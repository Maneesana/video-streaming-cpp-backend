
#ifndef SwaggerComponent_hpp
#define SwaggerComponent_hpp

#include "oatpp-swagger/Model.hpp"
#include "oatpp-swagger/Resources.hpp"
#include "oatpp/macro/component.hpp"
#include <cstdlib>
/**
 *  Swagger ui is served at
 *  http://host:port/swagger/ui
 */
class SwaggerComponent
{
public:
  /**
   *  General API docs info
   */
  OATPP_CREATE_COMPONENT(std::shared_ptr<oatpp::swagger::DocumentInfo>, swaggerDocumentInfo)([]
                                                                                             {
                                                                                               oatpp::swagger::DocumentInfo::Builder builder;

                                                                                               builder
                                                                                                   .setTitle("User entity service")
                                                                                                   .setDescription("CRUD API Example project with swagger docs")
                                                                                                   .setVersion("1.0")
                                                                                                   .setContactName("Ivan Ovsyanochka")
                                                                                                   .setContactUrl("https://oatpp.io/")

                                                                                                   .setLicenseName("Apache License, Version 2.0")
                                                                                                   .setLicenseUrl("http://www.apache.org/licenses/LICENSE-2.0")

                                                                                                   .addServer("http://localhost:8000", "server on localhost");

                                                                                               return builder.build(); }());

  /**
   *  Swagger-Ui Resources (<oatpp-examples>/lib/oatpp-swagger/res)
   */
  OATPP_CREATE_COMPONENT(std::shared_ptr<oatpp::swagger::Resources>, swaggerResources)([]
                                                                                       {
     const char* resPath = std::getenv("OATPP_SWAGGER_RES_PATH");
    if (!resPath) {
      throw std::runtime_error("OATPP_SWAGGER_RES_PATH environment variable is not set");
    }
    return oatpp::swagger::Resources::loadResources(resPath); }());
};

#endif /* SwaggerComponent_hpp */
