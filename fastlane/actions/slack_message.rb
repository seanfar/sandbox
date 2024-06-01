# frozen_string_literal: true

require 'slack-ruby-client'
require 'openssl'

# Print OpenSSL version and default paths
puts "OpenSSL version: #{OpenSSL::OPENSSL_VERSION}"
puts "Default SSL cert file: #{OpenSSL::X509::DEFAULT_CERT_FILE}"
puts "Default SSL cert dir: #{OpenSSL::X509::DEFAULT_CERT_DIR}"

# Check environment variables
puts "SSL_CERT_FILE: #{ENV['SSL_CERT_FILE']}"
puts "SSL_CERT_DIR: #{ENV['SSL_CERT_DIR']}"

# Print default cert store paths
store = OpenSSL::X509::Store.new
puts "Default cert store paths: #{store.set_default_paths}"

module Fastlane
  module Actions
    class SlackMessageAction < Action
      GITHUB_RUN_URL = "https://github.com/justworkshr/clockwork_mobile/actions/runs/#{ENV['GITHUB_RUN_ID']}".freeze

      MOBILE_SLACK_CHANNELS = {
        test_vibe: 'C0658GLTQF7',
        mobile_eng: 'C04MU5Y554K',
        mobile_cicd: 'C04BXBCBZEJ',
        mobile_release: 'C031XU1PDPH'
      }.freeze

      def self.run(params)
        other_action.ensure_env_vars(env_vars: ['SLACK_MOBILE_BOT_TOKEN'])

        Actions.lane_context[Fastlane::Actions::SharedValues::PLATFORM_NAME] = params[:platform] if params[:platform]

        # Initialize the Slack client with your OAuth token
        @client = initialize_slack_client

        if params[:e2e_results]
          report_e2e_results(params[:e2e_results])
        else
          report_deploy_results
        end
      end

      def self.initialize_slack_client
        Slack.configure do |config|
          config.token = ENV['SLACK_MOBILE_BOT_TOKEN']
        end

        Slack::Web::Client.new
      end

      def self.report_e2e_results(
        results,
        platform = Actions.lane_context[Fastlane::Actions::SharedValues::PLATFORM_NAME]
      )
        params = JSON.parse(results, symbolize_names: true)

        result_message = @client.chat_postMessage(
          channel: MOBILE_SLACK_CHANNELS[:test_vibe],
          as_user: true,
          blocks: [
            {
              "type": 'header',
              "text": {
                "type": 'plain_text',
                "text": "E2E Test Results - #{platform.capitalize}",
                "emoji": true
              }
            },
            {
              "type": 'divider'
            },
            {
              "type": 'context',
              "elements": [
                {
                  "type": 'mrkdwn',
                  "text": [
                    ":white_check_mark: #{params[:numPassedTests]} Passing",
                    ":x: #{params[:numFailedTests]} Failed",
                    ":warning: #{params[:numSkippedTests]} Skipped"
                  ].join('    ')
                }
              ]
            },
            *create_footer(threaded: params[:numFailedTests].positive?)
          ]
        )

        return unless params[:groupedTestResults]

        ## Create the test results blocks
        blocks = [
          {
            "type": 'header',
            "text": {
              "type": 'plain_text',
              "text": ':x: Failed tests',
              "emoji": true
            }
          },
          {
            "type": 'divider'
          }
        ]

        params[:groupedTestResults].each do |key, values|
          blocks << {
            "type": 'rich_text',
            "elements": [
              {
                "type": 'rich_text_list',
                "style": 'bullet',
                "indent": 0,
                "border": 1,
                "elements": [
                  {
                    "type": 'rich_text_section',
                    "elements": [
                      {
                        "type": 'text',
                        "text": key,
                        "style": {
                          "code": true,
                          "bold": true
                        }
                      }
                    ]
                  }
                ]
              },
              {
                "type": 'rich_text_list',
                "style": 'bullet',
                "indent": 1,
                "border": 1,
                "elements": values.map do |value|
                  {
                    "type": 'rich_text_section',
                    "elements": [
                      {
                        "type": 'text',
                        "text": value,
                        "style": {
                          "code": true
                        }
                      }
                    ]
                  }
                end
              }
            ]
          }
        end

        @client.chat_postMessage(
          channel: MOBILE_SLACK_CHANNELS[:test_vibe],
          as_user: true,
          thread_ts: result_message['ts'],
          blocks:
        )
      end

      def self.report_deploy_results
        platform = Actions.lane_context[Fastlane::Actions::SharedValues::PLATFORM_NAME]
        current_version = Actions.lane_context[SharedValues::VERSION_NUMBER]
        current_build = Actions.lane_context[SharedValues::BUILD_NUMBER]

        @client.chat_postMessage(
          channel: MOBILE_SLACK_CHANNELS[:test_vibe],
          as_user: true,
          blocks: [
            {
              "type": 'header',
              "text": {
                "type": 'plain_text',
                "text": 'Deployment Results',
                "emoji": true
              }
            },
            {
              "type": 'divider'
            },
            {
              "type": 'section',
              "text": {
                "type": 'mrkdwn',
                "text": 'The deployment has been completed successfully! :tada:'
              }
            },
            {
              "type": 'section',
              "fields": [
                {
                  "type": 'mrkdwn',
                  "text": "*Platform:*\n#{platform == :ios ? 'iOS' : 'Android'}"
                },
                {
                  "type": 'mrkdwn',
                  "text": "*Version:*\n#{current_version}"
                },
                {
                  "type": 'mrkdwn',
                  "text": "*Build:*\n#{current_build}"
                },
                {
                  "type": 'mrkdwn',
                  "text": "*Environment:*"
                }
              ]
            },
            *create_footer
          ]
        )
      end

      def self.create_footer(threaded: false)
        [
          if ENV['GITHUB_RUN_ID']
            {
              "type": 'context',
              "elements": [
                {
                  "type": 'mrkdwn',
                  "text": "*Check the run execution <#{GITHUB_RUN_URL}|HERE>.*"
                }
              ]
            }
          end,
          if threaded
            {
              "type": 'context',
              "elements": [
                {
                  "type": 'mrkdwn',
                  "text": '_See :thread: for more details._'
                }
              ]
            }
          end
        ].compact
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        'Sends a slack message to the specified webhook URL.'
      end

      def self.available_options
        # Define all options your action supports.
        [
          FastlaneCore::ConfigItem.new(
            key: :exception,
            description: 'The exception to include in the slack message',
            is_string: true,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :e2e_results,
            description: 'The stringified JSON object containing the e2e test results',
            is_string: true,
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :platform,
            description: 'The platform the slack message is intended for',
            is_string: true,
            optional: true
          )
        ]
      end

      def self.is_supported?(_platform)
        true
      end
    end
  end
end
