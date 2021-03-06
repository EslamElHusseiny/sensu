class TestSensuAPI < TestCase
  def setup
    @options = {:config_file => File.join(File.dirname(__FILE__), 'config.json')}
    config = Sensu::Config.new(@options)
    @settings = config.settings
    @api = 'http://' + @settings.api.host + ':' + @settings.api.port.to_s
  end

  def test_get_events
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api + '/events').get
      http.callback do
        assert_equal(200, http.response_header.status)
        events = JSON.parse(http.response)
        assert(events.is_a?(Hash))
        assert_block "Response didn't contain the test event" do
          events.any? do |client, events|
            if client == @settings.client.name
              events.keys.any? do |check|
                check == 'test'
              end
            end
          end
        end
        done
      end
    end
  end

  def test_get_clients
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api + '/clients').get
      http.callback do
        assert_equal(200, http.response_header.status)
        clients = JSON.parse(http.response)
        assert(clients.is_a?(Array))
        assert_block "Response didn't contain the test client" do
          clients.any? do |client|
            client['name'] == @settings.client.name
          end
        end
        done
      end
    end
  end

  def test_get_checks
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api + '/checks').get
      http.callback do
        assert_equal(200, http.response_header.status)
        checks = JSON.parse(http.response)
        assert(checks.is_a?(Hash))
        assert_equal(checks, @settings.checks.to_hash)
        done
      end
    end
  end

  def test_get_event
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api + '/event/' + @settings.client.name + '/test').get
      http.callback do
        assert_equal(200, http.response_header.status)
        expected = {
          :status => 2,
          :output => "CRITICAL\n",
          :flapping => false,
          :occurrences => 1
        }
        assert_equal(expected, (JSON.parse(http.response).reject { |key, value| key == 'issued' }).symbolize_keys)
        done
      end
    end
  end

  def test_resolve_event
    Sensu::API.run_test(@options) do
      options = {
        :body => '{"client": "' + @settings.client.name + '", "check": "test"}'
      }
      http = EM::HttpRequest.new(@api + '/event/resolve').post options
      http.callback do
        assert_equal(201, http.response_header.status)
        done
      end
    end
  end

  def test_resolve_nonexistent_event
    Sensu::API.run_test(@options) do
      options = {
        :body => '{"client": "' + @settings.client.name + '", "check": "nonexistent"}'
      }
      http = EM::HttpRequest.new(@api + '/event/resolve').post options
      http.callback do
        assert_equal(404, http.response_header.status)
        done
      end
    end
  end

  def test_resolve_event_malformed
    Sensu::API.run_test(@options) do
      options = {
        :body => 'malformed'
      }
      http = EM::HttpRequest.new(@api + '/event/resolve').post options
      http.callback do
        assert_equal(400, http.response_header.status)
        done
      end
    end
  end

  def test_get_client
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api + '/client/' + @settings.client.name).get
      http.callback do
        assert_equal(200, http.response_header.status)
        assert_equal(@settings.client, JSON.parse(http.response).reject { |key, value| key == 'timestamp' })
        done
      end
    end
  end

  def test_get_nonexistent_client
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api + '/client/nonexistent').get
      http.callback do
        assert_equal(404, http.response_header.status)
        done
      end
    end
  end

  def test_delete_client
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api + '/client/' + @settings.client.name).delete
      http.callback do
        assert_equal(204, http.response_header.status)
        done
      end
    end
  end

  def test_delete_nonexistent_client
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api + '/client/nonexistent').delete
      http.callback do
        assert_equal(404, http.response_header.status)
        done
      end
    end
  end

  def test_get_check
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api + '/check/a').get
      http.callback do
        assert_equal(200, http.response_header.status)
        assert_equal(@settings.checks.a.to_hash, JSON.parse(http.response))
        done
      end
    end
  end

  def test_get_nonexistent_check
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api + '/check/nonexistent').get
      http.callback do
        assert_equal(404, http.response_header.status)
        done
      end
    end
  end

  def test_check_request
    Sensu::API.run_test(@options) do
      options = {
        :body => '{"check": "a", "subscribers": ["a", "b"]}'
      }
      http = EM::HttpRequest.new(@api + '/check/request').post options
      http.callback do
        assert_equal(201, http.response_header.status)
        done
      end
    end
  end

  def test_check_request_malformed
    Sensu::API.run_test(@options) do
      options = {
        :body => '{"check": "a", "subscribers": "malformed"}'
      }
      http = EM::HttpRequest.new(@api + '/check/request').post options
      http.callback do
        assert_equal(400, http.response_header.status)
        done
      end
    end
  end

  def test_create_stash
    Sensu::API.run_test(@options) do
      options = {
        :body => '{"key": "value"}'
      }
      http = EM::HttpRequest.new(@api + '/stash/tester').post options
      http.callback do
        assert_equal(201, http.response_header.status)
        done
      end
    end
  end

  def test_get_stash
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api + '/stash/test/test').get
      http.callback do |response|
        assert_equal(200, http.response_header.status)
        done
      end
    end
  end

  def test_get_stashes
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api + '/stashes').get
      http.callback do
        assert_equal(200, http.response_header.status)
        stashes = JSON.parse(http.response)
        assert(stashes.is_a?(Array))
        assert_block "Response didn't contain a test stash" do
          stashes.any? do |path, stash|
            ['test/test', 'tester'].include?(path)
          end
        end
        done
      end
    end
  end

  def test_multi_get_stashes
    Sensu::API.run_test(@options) do
      options = {
        :body => '["test/test", "tester"]'
      }
      http = EM::HttpRequest.new(@api + '/stashes').post options
      http.callback do
        assert_equal(200, http.response_header.status)
        stashes = JSON.parse(http.response)
        assert(stashes.is_a?(Hash))
        assert_block "Response didn't contain a test stash" do
          stashes.any? do |path, stash|
            ['test/test', 'tester'].include?(path)
          end
        end
        done
      end
    end
  end

  def test_delete_stash
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api + '/stash/test/test').delete
      http.callback do |response|
        assert_equal(204, http.response_header.status)
        done
      end
    end
  end
end
