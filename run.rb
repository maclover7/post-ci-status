require 'rest-client'
require 'json'

class Updater
  JOB_MAP = {
    'node-test-commit-arm-fanned' => 'test/arm-fanned',
    'node-test-commit-freebsd' => 'test/freebsd',
    'node-test-commit-linux' => 'test/linux',
    'node-test-commit-plinux' => 'test/ppc-linux',
    'node-test-commit-osx' => 'test/osx',
    'node-test-commit-smartos' => 'test/smartos',
    'node-test-commit-linux-fips' => 'test/linux-fips',
    'node-test-commit-aix' => 'test/aix',
    'node-test-commit-linuxone' => 'test/linux-one',
    'node-test-commit-windows-fanned' => 'test/windows-fanned',
    'node-test-linter' => 'linter'
  }

  def run
    puts 'node-test-commit job you would like updated:'
    root_job_id = gets.strip!

    root_job = JSON.parse(RestClient.get("https://ci.nodejs.org/job/node-test-commit/#{root_job_id}/api/json").body)

    root_job['subBuilds'].each do |sub_build|
      if sub_build['result'] == 'SUCCESS'
        status = 'success'
      else
        status = 'failure'
      end

      next unless JOB_MAP[sub_build['jobName']] == 'linter' || JOB_MAP[sub_build['jobName']] == 'test/osx'

      trigger_update_build({
        'IDENTIFIER' => JOB_MAP[sub_build['jobName']],
        'STATUS' => status,
        'URL' => "https://ci.nodejs.org/#{sub_build['url']}",
        'COMMIT' => root_job['changeSet']['items'][0]['commitId'],
        'REF' => root_job['actions'][0]['parameters'].find { |p| p['name'] == 'GIT_REMOTE_REF' }['value']
      })
    end
  end

  private

  def trigger_update_build(params)
    serializedParams = params.map do |name, value|
      "#{name}=#{value}"
    end

    base_url = 'https://ci.nodejs.org/view/MyJobs/job/post-build-status-update/buildWithParameters'
    url = "#{base_url}?token=#{ENV['JENKINS_TOKEN']}&#{serializedParams.join('&')}"

    begin
      RestClient.get(url)
    rescue => e
      require 'pry'; binding.pry
    end
  end
end

Updater.new.run
