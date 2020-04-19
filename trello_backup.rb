# frozen_string_literal: true

require 'forwardable'
require 'open-uri'
require 'json'
require 'yaml'
require 'fileutils'
require 'pathname'

class Helpers # rubocop:disable Style/Documentation
  extend Forwardable
  def_delegator :'self.class', :request

  def self.config
    @config ||= YAML.load_file(File.expand_path('~/.trello_backup.yml'))
  end

  # https://developer.atlassian.com/cloud/trello/rest/
  def self.request(path, params = '')
    auth = "key=#{config['developer_public_key']}&" \
           "token=#{config['member_token']}"
    prefix = 'https://api.trello.com/1/'
    url = "#{prefix}#{path}?#{auth}&#{params}"

    JSON.parse(URI.open(url).read)
  end

  # Aus https://github.com/rails/rails/blob/157920aead96865e3135f496c09ace607d5620dc/activestorage/app/models/active_storage/filename.rb#L57
  def sanitize_filename(name)
    name
      .encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: '�')
      .strip
      .tr("\u{202E}%$|:;/\t\r\n\\", '-')
  end

  def write(json:, to:)
    IO.write(to, JSON.pretty_generate(json))
  end
end

class Board < Helpers # rubocop:disable Style/Documentation
  def initialize(id)
    @id = id
  end

  def self.all
    request('members/me/boards').map { |data| Board.new(data['id']) }
  end

  def dump_to(backup_path)
    response = request "boards/#{@id}", 'cards=all&lists=all&checklists=all'

    board_path = backup_path / sanitize_filename(response['name'])
    FileUtils.mkdir board_path

    write json: response, to: "#{board_path}.json"

    response['cards'].each do |card|
      Card.new(card).dump_to board_path
    end
  end
end

class Card < Helpers # rubocop:disable Style/Documentation
  def initialize(data)
    @data = data
  end

  def dump_to(base_path)
    dump_actions_to(base_path)
    dump_attachments_to(base_path)
  end

  private

  def dump_attachments_to(base_path)
    return unless attachments?

    path = card_path base_path
    write json: attachment_data, to: path / 'attachments.json'
    uploaded_attachments.each do |attachment|
      IO.write(path / attachment['name'], URI.open(attachment['url']).read)
    end
  end

  def dump_actions_to(base_path)
    return unless comments?

    path = card_path base_path
    write json: action_data, to: path / 'actions.json'

    # https://developer.atlassian.com/cloud/trello/guides/rest-api/rate-limits/
    sleep 0.1
  end

  def attachments?
    !@data['badges']['attachments'].zero?
  end

  def attachment_data
    @attachment_data ||= request 'attachments'
  end

  def comments?
    !@data['badges']['comments'].zero?
  end

  def action_data
    request 'actions'
  end

  def uploaded_attachments
    attachment_data.select { |attachment| attachment['isUpload'] }
  end

  def card_path(base_path)
    path = base_path / sanitize_filename(@data['name'])
    FileUtils.mkdir_p path
    path
  end

  def request(sub_resource)
    super "cards/#{@data['id']}/#{sub_resource}"
  end
end

backup_path = Pathname.new Dir.pwd
Board.all.each { |board| board.dump_to backup_path }
