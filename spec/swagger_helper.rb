# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'API V1',
        version: 'v1'
      },
      paths: {},
      servers: [
        {
          url: 'http://localhost:3000'
        }
      ],
      components: {
        schemas: {
          Category: {
            type: :object,
            description: 'A category used to classify points of interest.',
            properties: {
              id: {
                type: :integer
              },
              name: {
                type: :string,
                example: 'Beach'
              },
              created_at: {
                type: :string,
                format: :'date-time'
              },
              updated_at: {
                type: :string,
                format: :'date-time'
              }
            },
            required: %w[id name]
          },

          Location: {
            type: :object,
            description: 'A geographical location.',
            properties: {
              id: {
                type: :integer
              },
              name: {
                type: :string,
                example: 'Lisbon'
              },
              region: {
                type: :string,
                example: 'Lisbon'
              },
              created_at: {
                type: :string,
                format: :'date-time'
              },
              updated_at: {
                type: :string,
                format: :'date-time'
              }
            },
            required: %w[id name region]
          },

          Poi: {
            type: :object,
            description: 'A point of interest with its associated categories.',
            properties: {
              id: {
                type: :integer
              },
              name: {
                type: :string,
                example: 'Belém Tower'
              },
              description: {
                type: :string,
                example: 'A historic fortified tower on the Tagus River.'
              },
              latitude: {
                type: :number,
                minimum: -90,
                maximum: 90,
                example: 38.6916
              },
              longitude: {
                type: :number,
                minimum: -180,
                maximum: 180,
                example: -9.216
              },
              created_at: {
                type: :string,
                format: :'date-time'
              },
              updated_at: {
                type: :string,
                format: :'date-time'
              },
              categories: {
                type: :array,
                items: {
                  '$ref' => '#/components/schemas/Category'
                }
              }
            },
            required: %w[
              id
              name
              description
              latitude
              longitude
              categories
            ]
          },

          Error: {
            type: :object,
            description: 'An error response.',
            properties: {
              error: {
                type: :string,
                example: 'bad request / not found'
              }
            },
            required: ['error']
          }
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
