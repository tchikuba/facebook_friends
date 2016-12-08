require 'bundler'
Bundler.require
require 'capybara/poltergeist'
require 'io/console'
require 'readline'

# タイムアウト値
MAX_WAIT_TIME = 60

# facebookの友人一覧オートロード件数
LOAD_FRIEND_COUNT = 20

# 偽装ユーザーエージェント
USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X)'

# capybaraの初期設定
Capybara.default_max_wait_time = MAX_WAIT_TIME
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new app, { timeout: MAX_WAIT_TIME }
end
Capybara.default_driver = :poltergeist
Capybara.javascript_driver = :poltergeist

def wait_until
  require 'timeout'
  Timeout.timeout MAX_WAIT_TIME do
    sleep 0.1 until value = yield
    value
  end
end

def find_intro_container(session)
  session.find '#intro_container_id'
rescue
  # 自己紹介が表示されない場合は無視
end

def friend_infos(session, friends_count)
  element = session.find '#pagelet_timeline_medley_friends'
  scroll_count = friends_count / LOAD_FRIEND_COUNT
  surplus = friends_count % LOAD_FRIEND_COUNT
  element.find 'ul'
  1.upto(scroll_count) do |i|
    session.evaluate_script 'window.scrollBy(0, 10000)'
    wait_until { element.find "ul:nth-of-type(#{i + 1})" }
  end

  (1..scroll_count + 1).map do |i|
    max_li_count = i == scroll_count + 1 ? surplus : LOAD_FRIEND_COUNT
    (1..max_li_count).map do |k|
      friend_info = element.find("ul:nth-of-type(#{i}) > li:nth-of-type(#{k}) .fsl.fwb.fcb")
      { name: friend_info.text, url: friend_info.find('a')['href'] }
    end
  end.flatten
end

def output_name_and_address(session, info)
  wait_until { session.visit info[:url] }
  intro_container = find_intro_container session
  address_class = intro_container.nil? ? nil : intro_container.all('ul > li').detect { |v| v['innerHTML'].include? '在住' }
  address = address_class.nil? ? '' : address_class.text.delete('在住')
  puts [info[:name], info[:url], address].join(',')
end

# FBログイン情報入力
puts 'Facebook login.'
print 'Email: '
email = STDIN.gets.chomp
password = STDIN.noecho { Readline.readline 'Password: ' }.tap { puts }
puts 'Start session.'

# セッション開始
session = Capybara::Session.new :poltergeist
session.driver.headers = { 'User-Agent' => USER_AGENT } 

# FBログイン
session.visit 'https://www.facebook.com'
session.fill_in 'email', with: email
session.fill_in 'pass', with: password
session.find('#loginbutton').click

# プロフィールページからすべての友達一覧へ遷移
session.find('#u_0_2 > div:nth-child(1) > div:nth-child(1) > div > a').click
timeline = session.find '#fbTimelineHeadline'
friends_count = timeline.find('a:nth-of-type(3) > span._gs6').text.to_i
timeline.click_on '友達'

# 友達一覧をスクロールしてすべての友達のリストを取得
scroll_count = friends_count / LOAD_FRIEND_COUNT
friend_infos = friend_infos session, friends_count

# 友達のプロフィールページから居住地を取得
friend_infos.each do |friend_info|
  output_name_and_address session, friend_info
end
