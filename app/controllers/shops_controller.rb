require 'httparty'

class ShopsController < ApplicationController
  def index
    # リクエストボディの作成
    request_body = {
      includedTypes: ["restaurant"],
      maxResultCount: 10,
      locationRestriction: {
        circle: {
          center: {
            latitude: params[:latitude].to_f,
            longitude: params[:longitude].to_f
          },
          radius: 500.0
        }
      }
    }

    # APIキーを環境変数から取得
    api_key = ENV['GOOGLE_MAPS_API_KEY']

    # HTTPリクエストヘッダーの設定
    headers = {
      "Content-Type" => "application/json",
      "X-Goog-Api-Key" => api_key,
      "X-Goog-FieldMask" => "places.id"
    }

    # APIエンドポイント
    url = "https://places.googleapis.com/v1/places:searchNearby"

    # HTTPartyでPOSTリクエストを送信
    response = HTTParty.post(
      url,
      body: request_body.to_json,
      headers: headers
    )

    places = response.parsed_response["places"]

    result = []

    places.each do |place|
      result << fetch_place_details(place["id"], api_key)
    end

    # # 詳細情報を取得して夜中2時まで営業しているかを判定
    # filtered_places = places.select do |place|
    #   place_id = place["place_id"]
    #   details = fetch_place_details(place_id, api_key)

    #   # 営業時間が取得できない場合は除外
    #   next false unless details && details["opening_hours"] && details["opening_hours"]["periods"]

    #   # 営業時間の判定
    #   open_late?(details["opening_hours"]["periods"])
    # end

    # # 必要な情報だけを整形して返す
    # result = filtered_places.map do |place|
    #   {
    #     name: place["name"],
    #     address: place["vicinity"],
    #     rating: place["rating"],
    #     location: place["geometry"]["location"]
    #   }
    # end

    render json: result
  end

  private

  # Place Details APIを呼び出して詳細情報を取得
  def fetch_place_details(place_id, api_key)
    # Google Places APIのエンドポイント
    url = "https://places.googleapis.com/v1/places/#{place_id}"

    # リクエストヘッダー
    headers = {
      "Content-Type" => "application/json",
      "X-Goog-Api-Key" => api_key,
      "X-Goog-FieldMask" => "*"
    }

    # GETリクエストを送信
    response = HTTParty.get(url, headers: headers)
    return nil unless response.code == 200

    response.parsed_response
  end

  # 夜中2時まで営業しているかを判定
  def open_late?(periods)
    # 今日が何曜日かを取得 (0: 日曜, 1: 月曜, ...)
    today = Time.now.wday

    # 今日の営業終了時間を取得
    today_period = periods.find { |period| period["close"]["day"] == today }
    return false unless today_period

    # 営業終了時間を解析
    closing_time = today_period["close"]["time"] # 例: "0200" (2時)
    closing_hour = closing_time[0..1].to_i
    closing_minute = closing_time[2..3].to_i

    # 終了時間が2時以降かどうか
    closing_hour > 2 || (closing_hour == 2 && closing_minute == 0)
  end
end
