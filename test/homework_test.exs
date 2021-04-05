defmodule HomeworkTest do
  # Import helpers
  use Hound.Helpers
  use ExUnit.Case

  defmacro assert_with_screenshot_on_failure(assertion) do
    quote do
      try do
        assert unquote(assertion)
      rescue
        error ->
          take_screenshot()
          raise error
      end
    end
  end

  # Start hound session and destroy when tests are run
  hound_session()

  test "A/B testing should give the same variant for an user" do
    url = "https://the-internet.herokuapp.com/"
    navigate_to(url)
    find_element(:xpath, "//a[contains(text(), 'A/B Testing')]") |> click()
    variation_selector = "//div[@class='example']/h3"
    variation = visible_text(find_element(:xpath, variation_selector))

    for _ <- 0..10 do
      refresh_page()
      assert_with_screenshot_on_failure variation == visible_text(find_element(:xpath, variation_selector))
    end
  end

  test "click on redirect link should take to a different url" do
    navigate_to("https://the-internet.herokuapp.com/")
    find_element(:xpath, ~s|//a[contains(text(), 'Redirect Link')]|) |> click()
    find_element(:xpath, ~s|//a[@href='redirect']|) |> click()
    assert_with_screenshot_on_failure current_url() == "https://the-internet.herokuapp.com/status_codes"
    assert_with_screenshot_on_failure current_path() == "/status_codes"
    assert_with_screenshot_on_failure visible_page_text() =~ "Status Codes"
  end

  test "multiple windows link should open a new window" do
    navigate_to("https://the-internet.herokuapp.com/")
    find_element(:xpath, ~s|//a[contains(text(), 'Multiple Windows')]|) |> click()
    find_element(:xpath, ~s|//a[@href='/windows/new']|) |> click()
    assert_with_screenshot_on_failure current_url() == "https://the-internet.herokuapp.com/windows"
    assert_with_screenshot_on_failure current_path() == "/windows"
  end

  test "all the status code links should redirect to right urls" do
    navigate_to("https://the-internet.herokuapp.com/")
    find_element(:xpath, ~s|//a[contains(text(), 'Status Codes')]|) |> click()

    status_codes = [200, 301, 404, 500]

    for status_code <- status_codes do
      find_element(:xpath, "//a[@href='status_codes/#{status_code}']") |> click()
      assert_with_screenshot_on_failure visible_page_text() =~ "This page returned a #{status_code} status code."
      find_element(:xpath, "//a[@href='/status_codes']") |> click()
    end
  end

  test "typos feature should show typo and correct text randomly" do
    navigate_to("https://the-internet.herokuapp.com/")
    find_element(:xpath, ~s|//a[contains(text(), 'Typos')]|) |> click()

    correct_text =
      "Typos\nThis example demonstrates a typo being introduced. It does it randomly on each page load.\nSometimes you'll see a typo, other times you won't.\nPowered by Elemental Selenium"

    bool_list =
      for _ <- 0..10 do
        text = visible_page_text()
        refresh_page()

        if text != correct_text do
          true
        else
          false
        end
      end

    assert_with_screenshot_on_failure Enum.any?(bool_list)
    assert_with_screenshot_on_failure !Enum.all?(bool_list)
  end

  test "create user should return 201" do
    name = "Nivya"
    job = "QA Engineer"

    body =
      Poison.encode!(%{
        name: name,
        job: job
      })

    headers = [{"Content-type", "application/json"}]

    url = "https://reqres.in/api/users"

    {:ok, %HTTPoison.Response{status_code: status_code, body: body}} =
      HTTPoison.post(url, body, headers, [])

      assert status_code == 201
    response_map = Poison.decode!(body)
    id = response_map["id"]
    assert response_map["name"] == name
    assert response_map["job"] == job

    {:ok, %HTTPoison.Response{status_code: status_code}} = HTTPoison.get("#{url}/#{id}")
    assert status_code == 404
  end

  test "get user should return expected user attributes" do
    url = "https://reqres.in/api/users"
    {:ok, %HTTPoison.Response{status_code: status_code, body: body}} = HTTPoison.get("#{url}/2")

    assert status_code == 200
    response_map = Poison.decode!(body)
    assert response_map["data"]["id"] == 2
    assert response_map["data"]["first_name"] == "Janet"
    assert response_map["data"]["last_name"] == "Weaver"
    assert response_map["data"]["email"] == "janet.weaver@reqres.in"
  end
end
