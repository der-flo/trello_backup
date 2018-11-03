require 'open-uri'
require 'json'
require 'yaml'
require 'fileutils'

backup_path = "backups/#{Date.today}"
FileUtils.mkdir_p backup_path

$config = YAML.load_file('config.yml')

def request path, params = ''
  auth = "key=#{$config['developer_public_key']}&" \
         "token=#{$config['member_token']}"
  prefix = 'https://api.trello.com/1/'
  url = "#{prefix}#{path}?#{auth}&#{params}"

  JSON.parse(open(url).read)
end

def sanitize_filename name
  name.gsub(/[^a-zA-Z0-9\.\-\+_]/, '_')
end

request('members/me/boards').each do |b|
  response = request "boards/#{b['id']}",
                     'cards=all&lists=all&checklists=all&' \
                     'actions=all&actions_limit=1000&' \
                     'action_member=false&action_memberCreator=false'

  board_pathname = File.join(backup_path, sanitize_filename(response['name']))
  IO.write("#{board_pathname}.json", JSON.pretty_generate(response))

  # Backup attachments
  response['actions']
    .select { |action| action['type'] == 'addAttachmentToCard' }
    .select do |action|
      url = action['data']['attachment']['url']
      url && url.include?('trello-attachments')
    end
    .each do |action|
      attachment = action['data']['attachment']
      FileUtils.mkdir_p board_pathname
      IO.write("#{board_pathname}/#{attachment['name']}",
               open(attachment['url']).read)
    end
end
