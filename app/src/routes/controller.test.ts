import { test, expect, describe, vi } from "vitest";
import app from "../app";

describe("HTTP routes", () => {
  test('GET / should return status code 200 and reply with "Hello world"', async () => {
    const responseMessage = "Hello world";
    const response = await app.inject({
      method: "GET",
      path: "/",
    });

    expect(response.statusCode).toBe(200);
    expect(response.body).toBe(responseMessage);
  });

  test('GET /500 should return status code 500 and reply with "Status code 500" ', async () => {
    const responseMessage = "Status code 500";
    const response = await app.inject({
      method: "GET",
      path: "/500",
    });

    expect(response.statusCode).toBe(500);
    expect(response.body).toBe(responseMessage);
  });

  test('GET /404 should return status code 404 and reply with "Status code 404" ', async () => {
    const responseMessage = "Status code 404";
    const response = await app.inject({
      method: "GET",
      path: "/404",
    });

    expect(response.statusCode).toBe(404);
    expect(response.body).toBe(responseMessage);
  });
  test("GET /error should return 500", async () => {
    const response = await app.inject({
      method: "GET",
      path: "/error",
    });

    expect(response.statusCode).toBe(500);
    expect(response.json()).toEqual({
      statusCode: 500,
      error: "Internal Server Error",
      message: "Something went pretty wrong",
    });
  });
  test("GET /flaky should return 503 when random value is below 0.1", async () => {
    vi.spyOn(Math, "random").mockReturnValue(0.05);

    const response = await app.inject({
      method: "GET",
      path: "/flaky",
    });

    expect(response.statusCode).toBe(503);
    expect(response.body).toBe("Temporarily Unavailable");

    vi.restoreAllMocks();
  });

  test("GET /flaky should return 200 when random value is 0.1 or higher", async () => {
    vi.spyOn(Math, "random").mockReturnValue(0.5);

    const response = await app.inject({
      method: "GET",
      path: "/flaky",
    });

    expect(response.statusCode).toBe(200);
    expect(response.body).toBe("Ok");

    vi.restoreAllMocks();
  });

  test("GET /slow should return 200", async () => {
    const response = await app.inject({
      method: "GET",
      path: "/slow",
    });

    expect(response.statusCode).toBe(200);
    expect(response.body).toBe("Ok");
  });
  test("GET /redirect should redirect to /", async () => {
    const response = await app.inject({
      method: "GET",
      path: "/redirect",
    });

    expect(response.statusCode).toBe(302);
    expect(response.headers.location).toBe("/");
  });
});
