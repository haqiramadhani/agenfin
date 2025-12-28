# frozen_string_literal: true

class SwaggerUiController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    # Read the swagger.yaml file
    yaml_path = Rails.root.join("public/api-docs/v1/swagger.yaml")
    swagger_yaml = File.read(yaml_path)

    # Render the Swagger UI HTML with the yaml embedded
    render html: <<~HTML.html_safe
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Sure API Documentation</title>
        <link rel="stylesheet" type="text/css" href="https://fonts.googleapis.com/css?family=Open+Sans:400,700|Source+Code+Pro:400,700" />
        <style>
          body { margin: 0; padding: 0; }
          #swagger-ui { height: 100vh; }
        </style>
      </head>
      <body>
        <div id="swagger-ui"></div>
        <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.11.0/swagger-ui-bundle.js" charset="UTF-8"></script>
        <script charset="UTF-8">
          window.onload = function() {
            const ui = SwaggerUIBundle({
              url: "#{request.base_url}/api-docs/v1/swagger.yaml",
              dom_id: '#swagger-ui',
              deepLinking: true,
              presets: [
                SwaggerUIBundle.presets.apis,
                SwaggerUIBundle.SwaggerUIStandalonePreset
              ],
              layout: "StandaloneLayout"
            });
          };
        </script>
      </body>
      </html>
    HTML
  end
end
