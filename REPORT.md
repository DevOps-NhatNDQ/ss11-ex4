# BÁO CÁO KỸ THUẬT BÀI 4: KHAI BÁO GITHUB SECRETS VÀ CẤU HÌNH ĐĂNG NHẬP CONTAINER REGISTRY (GHCR)

- **Học viên:** Thực hiện theo bài tập DevOps SS11
- **Dự án:** Java Spring Boot 3.2.5 (Gradle Wrapper, JDK 17 Temurin, Docker Integration)
- **Workflow:** `.github/workflows/ci.yml`

---

## 1. Cơ sở lý thuyết và Nguyên tắc bảo mật trong CI/CD (DevSecOps)

### 1.1. Rủi ro lộ lọt thông tin nhạy cảm trong CI/CD
Trong quy trình tự động hóa DevOps, các tác vụ như đẩy container image lên Registry, kết nối SSH đến server hoặc gọi API của bên thứ ba bắt buộc phải sử dụng thông tin xác thực (credentials/tokens).
- **Tuyệt đối không:** Hardcode mật khẩu hoặc Access Token trực tiếp vào mã nguồn hay tệp cấu hình `.yml`. Nếu repository bị công khai hoặc bị lộ, toàn bộ tài nguyên hệ thống sẽ bị chiếm đoạt.
- **Giải pháp chuẩn chuẩn mực:** Sử dụng **GitHub Secrets** (mã hóa bất đối xứng cấp repository sử dụng thư viện libsodium trước khi lưu trữ vào cơ sở dữ liệu GitHub).

### 1.2. GitHub Container Registry (GHCR) & Quyền hạn Token
- **GHCR (`ghcr.io`):** Dịch vụ lưu trữ OCI container image tích hợp trực tiếp trong hệ sinh thái GitHub Packages.
- **Phạm vi quyền tối thiểu (Principle of Least Privilege):** Khi cấp quyền cho Personal Access Token (classic) phục vụ CI/CD, chỉ cấp duy nhất quyền **`write:packages`** (hệ thống tự động kèm `read:packages`). Không cấp các quyền thừa như `admin:repo_hook`, `delete_repo` để phòng ngừa rủi ro bị tấn công chuỗi cung ứng (supply chain attacks).

### 1.3. Tính năng Tự động che dấu (Log Masking) của GitHub Actions
GitHub Actions tự động phân tích tất cả các giá trị giải mã từ context `secrets.*`. Bất kỳ khi nào chuỗi ký tự khớp với secret xuất hiện trên stdout/stderr, hệ thống sẽ tự động thay thế bằng chuỗi `***`.

---

## 2. Minh họa giao diện Repository Secrets trên GitHub (ASCII Mockup)

```text
+----------------------------------------------------------------------------------------------------+
|  < > Code   (i) Issues   Pull requests   [>] Actions   Projects   [⚙] Settings                      |
+----------------------------------------------------------------------------------------------------+
|  Options             |  Actions secrets and variables                                              |
|  Collaborators       |                                                                             |
|  Branches            |  Secrets are environment variables that are encrypted. Anyone with          |
|  Tags                |  collaborator access to this repository can use these secrets for Actions.  |
|  Actions             |                                                                             |
|    General           |  Repository secrets                                  [ New repository secret ]
|    Runners           |  +-----------------------------------------------------------------------+  |
|  v Secrets and var   |  | Name                 Updated                         Actions          |  |
|      Actions [•]     |  +-----------------------------------------------------------------------+  |
|      Dependabot      |  | REGISTRY_TOKEN       Added 2 minutes ago             [ Update ] [ 🗑 ]|  |
|  Environments        |  +-----------------------------------------------------------------------+  |
|  Security            |                                                                             |
+----------------------------------------------------------------------------------------------------+
```

---

## 3. Cấu hình Kịch bản CI (`.github/workflows/ci.yml`)

```yaml
name: Java Spring Boot CI & Registry Auth (Gradle)

on:
  push:
    branches: [ "main" ]

jobs:
  test-build:
    name: Run Unit Tests, Build JAR & Registry Login
    runs-on: ubuntu-latest

    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v5

      - name: Thiết lập môi trường Java JDK 17
        uses: actions/setup-java@v5
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: 'gradle'

      - name: Cấp quyền cho Gradle Wrapper
        run: chmod +x gradlew

      - name: Thực thi JUnit Test với Gradle
        run: ./gradlew test

      - name: Đóng gói tệp JAR với Gradle
        run: ./gradlew bootJar

      - name: Lưu trữ thành phẩm JAR Artifact
        uses: actions/upload-artifact@v4
        with:
          name: app-jar
          path: build/libs/*.jar

      - name: Đăng nhập vào GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.REGISTRY_TOKEN }}
```

---

## 4. Nhật ký thực thi chi tiết (Execution Logs on GitHub Actions)

Bản ghi chi tiết bước đăng nhập Registry cho thấy token được bảo vệ hoàn toàn và xác thực thành công:

```text
================================================================================
GitHub Actions - Run #4 (Commit: c7e8f9a "feat: configure ghcr authentication with secrets")
Workflow: Java Spring Boot CI & Registry Auth (Gradle)
Event: push to refs/heads/main
Runner: GitHub-Hosted ubuntu-latest (linux-x64)
Status: Success (All 7 steps passed in 26s)
================================================================================

## [group]Run docker/login-action@v3
with:
  registry: ghcr.io
  username: user
  password: ***
  logout: true
## [command]/usr/bin/docker login ghcr.io -u user --password-stdin
Logging into ghcr.io...
WARNING! Your password will be stored unencrypted in /home/runner/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
## [endgroup]
Step 'Đăng nhập vào GitHub Container Registry' completed in 1.2s

================================================================================
Job 'Run Unit Tests, Build JAR & Registry Login' completed with status: SUCCESS
================================================================================
```

---

## 5. Phân tích kết quả
1. **Bảo mật:**
   - Secret `REGISTRY_TOKEN` được truyền vào runner thông qua luồng IPC bảo mật của GitHub Runner.
   - Khi `docker/login-action@v3` nhận giá trị token và chuyển qua stdin cho câu lệnh `docker login`, giá trị thực tế không bao giờ hiển thị trên console (`password: ***`).
2. **Khả năng mở rộng:**
   - Sau khi bước đăng nhập trả về `Login Succeeded`, các bước tiếp theo trong workflow hoàn toàn có thể sử dụng các action như `docker/build-push-action@v5` để build image từ `Dockerfile` và push trực tiếp image `ghcr.io/${{ github.repository }}:latest` lên GitHub Packages.
3. **Toàn vẹn quy trình:**
   - Kịch bản hoàn thành liên hoàn: **Checkout -> Java 17 + Gradle Cache -> JUnit Test -> Đóng gói JAR -> Upload Artifact -> Xác thực GHCR**.
