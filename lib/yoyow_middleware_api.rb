# frozen_string_literal: true

require 'json'

module ::YoyowRetorts

  class InvalidApiResponse < ::StandardError; end

  class YoyowMiddlewareAPI
    include Singleton

    def initialize
      # @url = url
      @conn = Faraday.new(SiteSetting.yoyow_middlware_api_url,
                          request: { timeout: 5 },
                          headers: { 'Content-Type' => 'application/json' }
      )
      @platform = SiteSetting.yoyow_platform_id
    end

    def encrypt( s )
      require('openssl')

      pass = SiteSetting.yoyow_middleware_sec_key
      salt = OpenSSL::Random.random_bytes(16)
      iv = OpenSSL::Random.random_bytes(16)

      key = OpenSSL::KDF.pbkdf2_hmac(
        pass,
        salt: salt,
        iterations: 100,
        length: 32,
        hash: 'sha1'
      )

      aes = OpenSSL::Cipher.new('AES-256-CBC')
      aes.encrypt
      aes.iv = iv
      aes.key = key

      cipher = aes.update(s)
      cipher << aes.final

      {
        s: salt.unpack('H*')[0],
        iv: iv.unpack('H*')[0],
        ct: cipher.unpack('H*')[0]
      }

    end

    def get_accounts_posts(account, platform, offset=0, limit=10)
      params = { poster: account,
                 platform: platform,
                 limit: limit,
                 offset: offset }

      resp = @conn.get('post_histories', params)
      res = JSON.parse(resp.body)
    end

    def get_csaf( account )
      resp = @conn.get("accounts/#{account}")
      resp_info = JSON.parse(resp.body)
      csaf = 0
      if resp_info["code"] == 0
        data = resp_info["data"]
        csaf = data["statistics"]["csaf"]
      end
      csaf
    end

    def get_accounts_scores(account, platform, offset, limit)
      params = { score_account: account,
                 platform: platform,
                 limit: limit,
                 offset: offset }

      resp = @conn.get('score_histories', params)
      res = JSON.parse(resp.body)
    end

    # 发文章
    def create_post_simple(poster, title, body, url, licence_lid, platform = nil, hash_value=nil)
      params = {
        poster: poster,
        title: title,
        body: body,
        url: url,
        license_lid: licence_lid,
        time: (Time.now.to_f * 10**3).to_i
      }
      params[:hash_value] = hash_value if hash_value
      params[:platform] = platform if platform

      encypted_params = encrypt(params.to_json)
      # puts encypted_params

      resp = @conn.post('posts/simple', encypted_params.to_json)
      # puts resp.body
      res = JSON.parse(resp.body)
    end

    # 点赞
    def score_a_post(account, platform, poster, pid, score, csaf)
      params = {
        from_account: account,
        platform: platform,
        poster: poster,
        pid: pid,
        score: score,
        csaf: csaf,
        time: (Time.now.to_f * 10**3).to_i
      }
      puts params

      encypted_params = encrypt(params.to_json)

      puts encypted_params

      resp = @conn.post('posts/score', encypted_params.to_json)
      #puts resp.body # 有中文编码报错的问题
      res = JSON.parse(resp.body)
      puts res
      res
    end

  end

end
