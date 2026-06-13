#include "pingController.h"

#include <QNetworkRequest>
#include <QUrl>
#include <QTimer>
#include <QElapsedTimer>
#include <optional>

#include "core/repositories/secureServersRepository.h"
#include "core/models/selfhosted/selfHostedAdminServerConfig.h"
#include "core/models/selfhosted/selfHostedUserServerConfig.h"
#include "core/models/selfhosted/nativeServerConfig.h"
#include "core/models/api/apiV2ServerConfig.h"
#include "core/utils/serverConfigUtils.h"

PingController::PingController(SecureServersRepository* serversRepository, QObject* parent)
    : QObject(parent)
    , m_serversRepository(serversRepository)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_autoRefreshTimer(new QTimer(this))
{
    m_autoRefreshTimer->setInterval(PING_INTERVAL_MS);
    connect(m_autoRefreshTimer, &QTimer::timeout, this, &PingController::pingAll);
}

QString PingController::hostForServer(const QString& serverId) const
{
    if (!m_serversRepository) return {};

    const auto kind = m_serversRepository->serverKind(serverId);

    switch (kind) {
    case serverConfigUtils::ConfigType::SelfHostedAdmin: {
        auto cfg = m_serversRepository->selfHostedAdminConfig(serverId);
        if (cfg.has_value()) return cfg->hostName;
        break;
    }
    case serverConfigUtils::ConfigType::SelfHostedUser: {
        auto cfg = m_serversRepository->selfHostedUserConfig(serverId);
        if (cfg.has_value()) return cfg->hostName;
        break;
    }
    case serverConfigUtils::ConfigType::Native: {
        auto cfg = m_serversRepository->nativeConfig(serverId);
        if (cfg.has_value()) return cfg->hostName;
        break;
    }
    case serverConfigUtils::ConfigType::AmneziaPremiumV2:
    case serverConfigUtils::ConfigType::AmneziaFreeV3:
    case serverConfigUtils::ConfigType::ExternalPremium: {
        auto cfg = m_serversRepository->apiV2Config(serverId);
        if (cfg.has_value() && !cfg->endpoints.isEmpty())
            return cfg->endpoints.first().host;
        break;
    }
    default:
        break;
    }
    return {};
}

QVector<PingController::PingEntry> PingController::buildEntries() const
{
    QVector<PingEntry> entries;
    if (!m_serversRepository) return entries;

    const int count = m_serversRepository->serversCount();
    for (int i = 0; i < count; ++i) {
        const QString serverId = m_serversRepository->serverIdAt(i);
        if (serverId.isEmpty()) continue;
        PingEntry e;
        e.serverId = serverId;
        e.hostName = hostForServer(serverId);
        e.lastPingMs = m_pingResults.value(serverId, INVALID_PING);
        if (!e.hostName.isEmpty()) {
            entries.append(e);
        }
    }
    return entries;
}

void PingController::pingAll()
{
    const QVector<PingEntry> entries = buildEntries();
    if (entries.isEmpty()) {
        emit pingAllFinished(QString());
        return;
    }

    m_pendingReplies = entries.size();

    for (const PingEntry& entry : entries) {
        // استفاده از HTTP HEAD request برای اندازه‌گیری latency
        QUrl url;
        url.setScheme("https");
        url.setHost(entry.hostName);
        url.setPort(443);
        url.setPath("/");

        QNetworkRequest request(url);
        request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                              QNetworkRequest::NoLessSafeRedirectPolicy);

        // ذخیره شناسه سرور در request
        const QString serverId = entry.serverId;
        auto* timer = new QElapsedTimer();
        timer->start();

        QNetworkReply* reply = m_networkManager->head(request);

        // تایم‌اوت
        QTimer* timeoutTimer = new QTimer(reply);
        timeoutTimer->setSingleShot(true);
        timeoutTimer->setInterval(PING_TIMEOUT_MS);
        connect(timeoutTimer, &QTimer::timeout, reply, [reply]() {
            reply->abort();
        });
        timeoutTimer->start();

        connect(reply, &QNetworkReply::finished, this,
                [this, reply, serverId, timer]() {
                    const qint64 elapsedMs = timer->elapsed();
                    delete timer;

                    int pingMs = INVALID_PING;
                    // NetworkError::OperationCanceledError = تایم‌اوت
                    // بقیه خطاها (SSL، redirect، etc.) هم latency دارند
                    if (reply->error() == QNetworkReply::NoError ||
                        reply->error() == QNetworkReply::OperationCanceledError) {

                        if (reply->error() == QNetworkReply::OperationCanceledError) {
                            pingMs = INVALID_PING; // timeout
                        } else {
                            pingMs = static_cast<int>(elapsedMs);
                        }
                    } else {
                        // سرور پاسخ داد ولی خطا داشت (مثل SSL) — latency معتبر است
                        if (elapsedMs < PING_TIMEOUT_MS) {
                            pingMs = static_cast<int>(elapsedMs);
                        }
                    }

                    m_pingResults[serverId] = pingMs;
                    emit pingResultUpdated(serverId, pingMs);
                    reply->deleteLater();

                    --m_pendingReplies;
                    if (m_pendingReplies <= 0) {
                        m_pendingReplies = 0;
                        emit pingAllFinished(bestServerId());
                    }
                });
    }
}

int PingController::getLastPing(const QString& serverId) const
{
    return m_pingResults.value(serverId, INVALID_PING);
}

QString PingController::bestServerId() const
{
    QString best;
    int bestMs = INT_MAX;

    for (auto it = m_pingResults.constBegin(); it != m_pingResults.constEnd(); ++it) {
        const int ms = it.value();
        if (ms != INVALID_PING && ms < bestMs) {
            bestMs = ms;
            best = it.key();
        }
    }
    return best;
}

void PingController::startAutoRefresh()
{
    if (!m_autoRefreshTimer->isActive()) {
        pingAll(); // یک بار فوری ping بزن
        m_autoRefreshTimer->start();
    }
}

void PingController::stopAutoRefresh()
{
    m_autoRefreshTimer->stop();
}
