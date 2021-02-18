# name: discourse-yoyow
# about: YOYOW Reactions plugin for Discourse
# version: 0.1.0
# authors: yoyow team

require 'auth/oauth2_authenticator' # oauth login

gem 'omniauth-yoyow','0.1.0'

register_svg_icon "yoyow-icon" if respond_to?(:register_svg_icon)

register_emoji "yo_custom", "/plugins/discourse-yoyow/images/YO-Custom.png"
register_emoji "yo_grin", "/plugins/discourse-yoyow/images/YO-Grin.png"
register_emoji "yo_laugh", "/plugins/discourse-yoyow/images/YO-Laugh.png"
register_emoji "yo_smile", "/plugins/discourse-yoyow/images/YO-Smile.png"

register_asset "stylesheets/retort.scss"
YOYOW_PLUGIN_NAME ||= "discourse-yoyow".freeze

enabled_site_setting :yoyow_enabled

class Auth::YOYOWAuthenticator < ::Auth::ManagedAuthenticator
  def name
    'yoyow'
  end

  def primary_email_verified?(auth_token)
    false  ## YOYOW暂不伪造邮箱返回，设置为false;根据代码来看影响不大
  end

  def register_middleware(omniauth)
    omniauth.provider :yoyow,
                      setup: lambda { |env|
                        strategy = env['omniauth.strategy']
                        strategy.options[:auth_server] = SiteSetting.yoyow_middlware_api_url
                        puts "------------- #{SiteSetting.yoyow_middlware_api_url}"
                        # strategy.options[:client_id] = SiteSetting.linkedin_client_id
                        # strategy.options[:client_secret] = SiteSetting.linkedin_secret
                      }
  end

  def after_authenticate(auth_token, existing_account: nil)
    result = super
    if result.user
      user = result.user
      user.custom_fields["yoyow_post_enabled"] = "true" if user.custom_fields["yoyow_post_enabled"].nil?
      user.custom_fields["yoyow_score_enabled"] = "true" if user.custom_fields["yoyow_score_enabled"].nil?
      user.custom_fields["yoyow_score_method"] = "fixed" if user.custom_fields["yoyow_score_method"].nil?
      user.custom_fields["yoyow_score_amount"] = 20 if user.custom_fields["yoyow_score_amount"].nil?
      user.custom_fields["yoyow_score_max_csaf"] = 1000 if user.custom_fields["yoyow_score_max_csaf"].nil?
      user.save_custom_fields
    end
    result
  end

  def after_create_account(user, auth)
    super
    user.custom_fields["yoyow_post_enabled"] = "true" if user.custom_fields["yoyow_post_enabled"].nil?
    user.custom_fields["yoyow_score_enabled"] = "true" if user.custom_fields["yoyow_score_enabled"].nil?
    user.custom_fields["yoyow_score_method"] = "fixed" if user.custom_fields["yoyow_score_method"].nil?
    user.custom_fields["yoyow_score_amount"] = 20 if user.custom_fields["yoyow_score_amount"].nil?
    user.custom_fields["yoyow_score_max_csaf"] = 1000 if user.custom_fields["yoyow_score_max_csaf"].nil?
    user.save_custom_fields
  end

  def enabled?
    SiteSetting.yoyow_enabled
  end

end

auth_provider authenticator: Auth::YOYOWAuthenticator.new, icon: 'yoyow-icon'

DiscoursePluginRegistry.serialized_current_user_fields << "yoyow_post_enabled"
DiscoursePluginRegistry.serialized_current_user_fields << "yoyow_score_enabled"
DiscoursePluginRegistry.serialized_current_user_fields << "yoyow_score_method"
DiscoursePluginRegistry.serialized_current_user_fields << "yoyow_score_amount"
DiscoursePluginRegistry.serialized_current_user_fields << "yoyow_score_max_csaf"


after_initialize do
  # 添加用户可修改属性
  User.register_custom_field_type('yoyow_post_enabled', :boolean)
  User.register_custom_field_type('yoyow_score_enabled', :boolean)
  User.register_custom_field_type('yoyow_score_method', :text)
  User.register_custom_field_type('yoyow_score_amount', :float)
  User.register_custom_field_type('yoyow_score_max_csaf', :float)

  register_editable_user_custom_field [:yoyow_post_enabled, :yoyow_score_enabled, :yoyow_score_method, :yoyow_score_amount, :yoyow_score_max_csaf ]

  module ::YoyowRetorts
    class Engine < ::Rails::Engine
      engine_name YOYOW_PLUGIN_NAME
      isolate_namespace YoyowRetorts
    end
  end

  [
    '../app/controllers/yoyow_explorer_controller.rb',
    '../lib/yoyow_middleware_api.rb',
  ].each { |path| load File.expand_path(path, __FILE__) }

  YoyowRetorts::Engine.routes.draw do
    get '/yoyow_posts' => 'yoyow_explorer#get_accounts_posts'
    get '/yoyow_scores' => 'yoyow_explorer#get_accounts_scores'
    post   "/:post_id" => "retorts#update"
  end

  Discourse::Application.routes.append do
    mount ::YoyowRetorts::Engine, at: "/yoyow_retorts"
  end

  class ::YoyowRetorts::RetortsController < ApplicationController
    before_action :verify_post_and_user, only: :update

    def update
      retort.toggle_user(current_user)
      respond_with_retort
    end

    private

    def post
      @post ||= Post.find_by(id: params[:post_id]) if params[:post_id]
    end

    def retort
      @retort ||= YoyowRetorts::Retort.find_by(post: post, retort: params[:retort])
    end

    def verify_post_and_user
      respond_with_unprocessable("Unable to find post #{params[:post_id]}") unless post
      respond_with_unprocessable("You are not permitted to modify this") unless current_user
    end

    def respond_with_retort
      if retort && retort.valid?
        MessageBus.publish "/retort/topics/#{params[:topic_id] || post.topic_id}", serialized_post_retorts
        render json: { success: :ok }
      else
        respond_with_unprocessable("Unable to save that retort. Please try again")
      end
    end

    def serialized_post_retorts
      ::PostSerializer.new(post.reload, scope: Guardian.new, root: false).as_json
    end

    def respond_with_unprocessable(error)
      render json: { errors: error }, status: :unprocessable_entity
    end
  end

  class ::YoyowRetorts::RetortSerializer < ActiveModel::Serializer
    attributes :post_id, :usernames, :emoji
    define_method :post_id,   -> { object.post_id }
    define_method :usernames, -> { object.persisted? ? JSON.parse(object.value) : [] }
    define_method :emoji,     -> { object.key.split('|').first }
  end

  ::YoyowRetorts::Retort = Struct.new(:detail) do

    def self.for_post(post: nil)
      PostDetail.where(extra: YOYOW_PLUGIN_NAME,
                       post: post)
    end

    def self.for_user(user: nil, post: nil)
      for_post(post: post).map    { |r| new(r) }
                          .select { |r| r.value.include?(user.username) }
    end

    def self.find_by(post: nil, retort: nil)
      new(for_post(post: post).find_or_initialize_by(key: :"#{retort}|#{YOYOW_PLUGIN_NAME}"))
    end

    def valid?
      detail.valid?
    end

    def toggle_user(user)
      new_value = if value.include? user.username
        value - Array(user.username)
      else
        purge_other_retorts!(user) unless SiteSetting.yoyow_retort_allow_multiple_reactions
        value + Array(user.username)
      end.flatten

      score_on_chain(user)

      if new_value.any?
        detail.update(value: new_value.flatten)
      else
        detail.destroy
      end
    end

    def score_on_chain(user)
      puts "**************************************"
      puts user.as_json
      puts detail.as_json
      puts detail.post.as_json

      # 如果插件没有开启 直接退出
      return unless SiteSetting.yoyow_enabled

      # 如果文章没有上链，不打分
      post_custom_settings = detail.post.custom_fields
      if post_custom_settings["yoyow_post_full_id"].blank?
        puts "文章没有上链，不打分"
        return
      end

      yoyow_id = user.user_associated_accounts.find_by_provider_name("yoyow")&.provider_uid
      # 如果 打分者 没有YOYO 账号， 或者 没有允许上链，不打分
      user_custom_settings = user.custom_fields
      if yoyow_id.blank? || user_custom_settings["yoyow_score_enabled"].blank?
        puts "打分者 没有YOYO 账号， 或者 没有允许上链，不打分"
        return
      end

      puts "用户允许打赏上链"
      return if yoyow_id == post_custom_settings["yoyow_poster"] # 不允许自己的账号给自己打分

      account_csaf = ::YoyowRetorts::YoyowMiddlewareAPI.instance.get_csaf(yoyow_id)

      # 根据 打分头像 和 用户配置 计算打分需要消耗的积分
      case detail.key
      when "yo_smile|#{YOYOW_PLUGIN_NAME}"
        csaf_to_score = account_csaf * SiteSetting.yoyow_score_smile_percent.to_f / 100
      when "yo_grin|#{YOYOW_PLUGIN_NAME}"
        csaf_to_score = account_csaf * SiteSetting.yoyow_score_grin_percent.to_f / 100
      when "yo_laugh|#{YOYOW_PLUGIN_NAME}"
        csaf_to_score = account_csaf * SiteSetting.yoyow_score_laugh_percent.to_f / 100
      when "yo_custom|#{YOYOW_PLUGIN_NAME}"
        puts "计算 自定义 打分的积分"
        if user_custom_settings["yoyow_score_method"] == 'fixed'
          csaf_to_score = user_custom_settings["yoyow_score_amount"].to_f * 1000
        elsif user_custom_settings["yoyow_score_method"] == 'ratio'
          score_ratio = user_custom_settings["yoyow_score_amount"].to_f / 100
          if score_ratio > 0 && score_ratio < 1
            csaf_to_score = account_csaf * score_ratio.to_f
          else
            csaf_to_score = 0
          end
        end
      else
        return
      end

      # 满足最少打分积分， 同时满足最大打分积分
      if csaf_to_score >= 1
        user_limit_score_csaf = (user_custom_settings["yoyow_score_max_csaf"].blank? ? 10000 : user_custom_settings["yoyow_score_max_csaf"].to_f)  * 1000
        system_limit_score_csaf = (SiteSetting.yoyow_max_score_csaf_once.blank? ? 10000 : SiteSetting.yoyow_max_score_csaf_once.to_f) * 1000
        puts [csaf_to_score, user_limit_score_csaf, system_limit_score_csaf]
        limit_csaf = [csaf_to_score, user_limit_score_csaf, system_limit_score_csaf].min

        if account_csaf > limit_csaf # 没有判断打分需要支付的手续费是否足够
          ::YoyowRetorts::YoyowMiddlewareAPI.instance.score_a_post(yoyow_id,
                                                           post_custom_settings["yoyow_platform"],
                                                           post_custom_settings["yoyow_poster"],
                                                           post_custom_settings["yoyow_post_pid"],
                                                           5,
                                                           limit_csaf.to_i)
        end
      end

    end

    def purge_other_retorts!(user)j
     self.class.for_user(user: user, post: detail.post).map { |r| r.toggle_user(user) }
    end

    def value
      return [] unless detail.value
      @value ||= Array(JSON.parse(detail.value))
    end
  end

  require_dependency 'post_serializer'
  class ::PostSerializer
    attributes :retorts

    def retorts
      return ActiveModel::ArraySerializer.new(YoyowRetorts::Retort.for_post(post: object), each_serializer: ::YoyowRetorts::RetortSerializer).as_json
    end
  end

  require_dependency 'rate_limiter'
  require_dependency 'post_detail'
  class ::PostDetail
    include RateLimiter::OnCreateRecord
    rate_limit :yoyow_rate_limiter
    after_update { run_callbacks :create if is_yoyow? }

    def is_yoyow?
      extra == YOYOW_PLUGIN_NAME
    end

    def yoyow_rate_limiter
      @rate_limiter ||= RateLimiter.new(yoyow_author, "create_yoyow", yoyow_max_per_day, 1.day.to_i) if is_yoyow?
    end

    def yoyow_author
      @yoyow_author ||= User.find_by(username: Array(JSON.parse(value)).last)
    end

    def yoyow_max_per_day
      (SiteSetting.yoyow_retort_max_per_day * yoyow_trust_multiplier).to_i
    end

    def yoyow_trust_multiplier
      return 1.0 unless yoyow_author&.trust_level.to_i >= 2
      SiteSetting.send(:"yoyow_retort_tl#{yoyow_author.trust_level}_max_per_day_multiplier")
    end
  end


  DiscourseEvent.on(:post_created) do |post, opts, user|
    puts "**********************"
    pp post   ## Post 22
    pp opts
    #  opts :  {"raw"=>"Testnew123 content Testnew123 content",
    # "archetype"=>"regular",
    # "category"=>"2",
    # "typing_duration_msecs"=>"3700",
    # "composer_open_duration_msecs"=>"11222",
    # "visible"=>true,
    # "is_warning"=>false,
    # "title"=>"Testnew123456789",
    # "ip_address"=>"127.0.0.1",
    # "user_agent"=>
    #  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36",
    # "referrer"=>"http://localhost:3000/",
    # "first_post_checks"=>true,
    # "is_poll"=>true}
    pp user   ## User 1

    # 判断3个条件
    # 1. 系统插件开启
    # 2. 用户绑定了yoyow，yoyow_id 存在
    # 3. 用户开启了yoyow_post_enabled， 允许文章上链
    if SiteSetting.yoyow_enabled
      yoyow_id = user.user_associated_accounts.find_by_provider_name("yoyow")&.provider_uid
      if yoyow_id && user.custom_fields["yoyow_post_enabled"] == true
        puts "用户允许发文到区块链"
        ## TODO ,做筛查。 如： 私信好像也是post,备份失败的信息也会创建post
        if post.topic.archetype == "regular"
          # 上链
          # title = post.topic.title
          title = "#{SiteSetting.title}_#{post.id}_#{post.external_id}"
          body = post.raw
          poster = yoyow_id
          platform = SiteSetting.yoyow_platform_id if SiteSetting.yoyow_platform_id
          license_lid = SiteSetting.yoyow_platform_license_lid #TODO
          # url 格式
          url = URI::join(SiteSetting.yoyow_content_url_domain_on_chain, 't/topic/', post.external_id)
          chain_result = ::YoyowRetorts::YoyowMiddlewareAPI.instance.create_post_simple(poster, title, body, url, license_lid, platform)
          puts chain_result
          if chain_result["code"] == 0
            block_num = chain_result["data"]["block_num"]
            txid = chain_result["data"]["txid"]
            chain_post = chain_result["data"]["post"]
            puts chain_post
            post.custom_fields["yoyow_platform"] = chain_post["platform"]
            post.custom_fields["yoyow_poster"] = chain_post["poster"]
            post.custom_fields["yoyow_post_pid"] = chain_post["post_pid"]
            post.custom_fields["yoyow_post_full_id"] = "#{chain_post["platform"]}_#{chain_post["poster"]}_#{chain_post["post_pid"]}"
            post.save_custom_fields
          end

        end
      end
    end
  end

end
