require 'httparty'

class ShopsController < ApplicationController
  def index
    # リクエストボディの作成
    request_body = {
      includedTypes: ["restaurant"],
      maxResultCount: 20,
      languageCode: "ja",
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

    # APIレスポンス確認用
    # filtered_places = []
    # places.map do |place|
    #   filtered_places << fetch_place_details(place["id"], api_key)
    # end

    # 詳細情報を取得して夜中2時まで営業しているかを判定
    filtered_places = []
    places.map do |place|
      details = fetch_place_details(place["id"], api_key)

      # 営業時間が取得できない場合は除外
      next unless details && details["currentOpeningHours"]

      # 営業時間の判定
      if open_late?(details)
        filtered_places << details
      end
    end

    # # 必要な情報だけを整形して返す
    # result = filtered_places.map do |place|
    #   {
    #     name: place["name"],
    #     address: place["vicinity"],
    #     rating: place["rating"],
    #     location: place["geometry"]["location"]
    #   }
    # end

    render json: filtered_places
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
      "X-Goog-FieldMask" => "displayName,currentOpeningHours",
    }

    # クエリ
    query = {
      languageCode: "ja"
    }

    # GETリクエストを送信
    response = HTTParty.get(url, headers: headers, query: query)
    return nil unless response.code == 200

    response.parsed_response
  end

  # 夜中2時まで営業しているかを判定
  def open_late?(details)
    weekday_descriptions = details["currentOpeningHours"]["weekdayDescriptions"]
    open_now = details["currentOpeningHours"]["openNow"]
    open_now_bool = if open_now == "true"
      true
    else
      false
    end
    # 今日が何曜日かを取得 (0: 日曜, 1: 月曜, ...)
    today = Time.now.wday

    # 今日の最終営業時間を取得
    today_description = weekday_descriptions[today - 1] # ex) 土曜日: 18時00分～0時00分
    return false if today_description.split(":")[1] == " 定休日"
    return true if today_description.split(":")[1] == " 24 時間営業"
    start_time_str = today_description.split(":")[1].split(",")[-1].split("～")[0]
    close_time_str = today_description.split(":")[1].split(",")[-1].split("～")[1]

    # 正規表現で時間と分を抽出
    start_match_data = start_time_str.match(/(\d+)時(\d+)分/)
    close_match_data = close_time_str.match(/(\d+)時(\d+)分/)

    # 開始時間と終了時間を取得
    start_hour = start_match_data[1].to_i
    start_minute = start_match_data[2].to_i
    close_hour = close_match_data[1].to_i
    close_minute = close_match_data[2].to_i

    return (start_hour > close_hour && close_hour >= 2)

  end
end
