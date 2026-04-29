# AiiDA Docker Quick Start

## 目录结构

```
aiida-docker-quickstart/
├── .env                 # 唯一的配置文件（所有参数在这里）
├── docker-compose.yml   # Docker Compose 配置
├── scripts/
│   └── entrypoint.sh    # 容器启动脚本
└── README.md
```

## 快速开始

### 1. 修改配置

编辑 `.env` 文件，修改以下必填项：

```ini
# 用户信息
USER_EMAIL=your.email@example.com
USER_FIRSTNAME=YourFirstName
USER_LASTNAME=YourLastName
USER_INSTITUTION=YourInstitution

# 密码（建议修改）
POSTGRES_PASSWORD=your_postgres_password
RABBITMQ_PASSWORD=your_rabbitmq_password
```

### 2. SSH 配置

SSH 配置使用 Docker volume `sshdata` 进行持久化：

- `SSH_KEY_DIR=/ssh_host` - SSH 密钥目录（只读）
- `SSH_CONFIG_DIR=/root/.ssh` - SSH 配置目录（读写）

**首次使用前**，需要在宿主机创建 SSH 密钥：

```bash
# 在宿主机（不是容器内）运行
cd ~
mkdir -p ssh_backup
cp .ssh/id_rsa ssh_backup/ 2>/dev/null || echo "No existing SSH key found"
cp .ssh/id_rsa.pub ssh_backup/ 2>/dev/null || echo "No existing SSH key found"
cp .ssh/config ssh_backup/ 2>/dev/null || echo "No existing SSH config found"
```

**手动添加 SSH 密钥到 volume**：

```bash
# 启动容器后，进入容器
docker-compose exec aiida bash

# 在容器内生成 SSH 密钥
ssh-keygen -t rsa -b 4096 -C "your.email@example.com" -f /root/.ssh/id_rsa

# 或者复制已有的密钥
# 将宿主机的 ~/.ssh/id_rsa 和 ~/.ssh/id_rsa.pub 
# 复制到容器内
```

### 3. 启动容器

```bash
# 启动所有服务
docker-compose up -d

# 查看容器状态
docker-compose ps

# 查看日志
docker-compose logs -f aiida
```

### 4. 进入容器

```bash
# 进入 AiiDA 容器
docker-compose exec aiida bash

# 或者直接使用 verdi 命令
docker-compose exec aiida verdi profile show
```

### 5. 验证安装

在容器内运行：

```bash
# 检查 AiiDA profile
verdi profile show

# 检查数据库连接
verdi daemon show
```

## 配置说明

`.env` 文件包含以下配置分组：

| 分组 | 变量 | 说明 |
|------|------|------|
| PostgreSQL | `POSTGRES_*` | 数据库连接参数 |
| RabbitMQ | `RABBITMQ_*` | 消息队列参数 |
| AiiDA User | `USER_*` | 用户信息 |
| AiiDA Profile | `PROFILE_NAME`, `REPO_URI` | AiiDA 配置 |
| SSH | `SSH_*_DIR` | SSH 配置目录 |

## 常用命令

```bash
# 停止所有服务
docker-compose down

# 停止并删除数据卷（慎用！会删除 SSH 密钥）
docker-compose down -v

# 重新启动
docker-compose restart

# 重新构建镜像
docker-compose build --no-cache

# 查看配置（不实际启动）
docker-compose config
```

## 故障排除

### 容器启动失败

```bash
# 查看详细日志
docker-compose logs -f

# 检查配置文件
docker-compose config
```

### 数据库连接失败

```bash
# 检查 PostgreSQL 是否就绪
docker-compose exec postgres pg_isready -U aiida_user

# 重试连接
docker-compose restart aiida
```

### RabbitMQ 连接失败

```bash
# 检查 RabbitMQ 状态
docker-compose exec rabbitmq rabbitmq-diagnostics -q ping

# 查看 RabbitMQ 日志
docker-compose logs rabbitmq
```

### SSH 连接失败

```bash
# 检查 SSH 配置
docker-compose exec aiida ls -la /ssh_host
docker-compose exec aiida ls -la /root/.ssh

# 在容器内测试 SSH
docker-compose exec aiida bash
ssh -v user@hostname
```

## 数据持久化

以下数据会持久化存储在 Docker volume 中：

- `pgdata` - PostgreSQL 数据库
- `rabbitdata` - RabbitMQ 消息队列
- `aiida_config` - AiiDA 配置
- `aiida_repo` - AiiDA 计算结果
- `sshdata` - SSH 密钥和配置

**重要**：`sshdata` volume 会持久化 SSH 密钥和配置，删除容器不会丢失 SSH 密钥。

删除数据卷命令（**会丢失所有数据，包括 SSH 密钥**）：

```bash
docker-compose down -v
```

## SSH 配置详解

### 为什么需要 SSH volume？

AiiDA 需要通过 SSH 连接到远程 HPC 服务器（如超算中心）来提交计算任务。SSH 密钥和配置需要持久化存储。

### 挂载说明

```yaml
volumes:
  - sshdata:/ssh_host:ro        # 只读挂载，用于 SSH 密钥
  - sshdata:/root/.ssh:rw       # 读写挂载，用于 SSH 配置和密钥
```

- `/ssh_host` - 供其他服务或脚本引用 SSH 密钥
- `/root/.ssh` - AiiDA 和 SSH 客户端使用的标准路径

### 首次配置

1. **方法一：在容器内生成新密钥**

```bash
docker-compose exec aiida bash
ssh-keygen -t rsa -b 4096 -C "your.email@example.com"
# 保存到默认位置：/root/.ssh/id_rsa
```

2. **方法二：从宿主机复制密钥**

```bash
# 宿主机上
docker-compose exec aiida bash
# 在容器外复制到 volume
docker cp ~/.ssh/id_rsa aiida-docker-quickstart_aiida_1:/root/.ssh/
docker cp ~/.ssh/id_rsa.pub aiida-docker-quickstart_aiida_1:/root/.ssh/
```

3. **添加 SSH 主机密钥到 known_hosts**

```bash
docker-compose exec aiida bash
ssh-keyscan -H hostname >> /root/.ssh/known_hosts
```

### 安全建议

- SSH 密钥存储在 Docker volume 中，定期备份 `sshdata` volume
- 使用强密码保护 SSH 私钥
- 不要将 SSH 密钥提交到代码仓库
