#ifndef PINGCONTROLLER_H
#define PINGCONTROLLER_H

#include <QObject>
#include <QMap>
#include <QTimer>
#include <QElapsedTimer>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QVector>

/**
 * PingController
 *
 * این کنترلر به‌صورت موازی تمام سرورها را ping می‌زند و نتایج را
 * از طریق signal به QML ارسال می‌کند. سپس می‌توان به بهترین سرور
 * (کمترین ping) متصل شد.
 *
 * روش کار:
 *   1. از ServersRepository لیست سرورها و hostname آن‌ها را می‌گیریم.
 *   2. برای هر سرور یک HTTP HEAD request به پورت 443 می‌زنیم
 *      و زمان پاسخ را اندازه می‌گیریم.
 *   3. نتایج از طریق pingResultUpdated() و pingAllFinished() به QML
 *      ارسال می‌شوند.
 */

class SecureServersRepository;

class PingController : public QObject
{
    Q_OBJECT

public:
    static constexpr int PING_TIMEOUT_MS = 5000;
    static constexpr int PING_INTERVAL_MS = 30000;
    static constexpr int INVALID_PING = -1;

    explicit PingController(SecureServersRepository* serversRepository,
                            QObject* parent = nullptr);
    ~PingController() override = default;

    /**
     * شروع ping همزمان تمام سرورها
     */
    Q_INVOKABLE void pingAll();

    /**
     * دریافت آخرین ping یک سرور خاص (بر حسب میلی‌ثانیه)
     * اگر هنوز ping نشده باشد INVALID_PING (-1) برمی‌گرداند.
     */
    Q_INVOKABLE int getLastPing(const QString& serverId) const;

    /**
     * بهترین serverId (کمترین ping معتبر) را برمی‌گرداند.
     * اگر هیچ سروری ping نشده باشد رشته خالی برمی‌گرداند.
     */
    Q_INVOKABLE QString bestServerId() const;

    /**
     * شروع خودکار ping در فواصل زمانی منظم
     */
    Q_INVOKABLE void startAutoRefresh();
    Q_INVOKABLE void stopAutoRefresh();

signals:
    /**
     * پس از اتمام ping هر سرور emit می‌شود.
     * @param serverId  شناسه سرور
     * @param pingMs    زمان پاسخ به میلی‌ثانیه، یا INVALID_PING اگر ناموفق بود
     */
    void pingResultUpdated(const QString& serverId, int pingMs);

    /**
     * پس از اتمام ping تمام سرورها emit می‌شود.
     * @param bestServerId  شناسه بهترین سرور (کمترین ping)
     */
    void pingAllFinished(const QString& bestServerId);

private slots:
    void onReplyFinished(QNetworkReply* reply, const QString& serverId,
                         const QElapsedTimer& timer);

private:
    struct PingEntry {
        QString serverId;
        QString hostName;
        int lastPingMs = INVALID_PING;
    };

    QVector<PingEntry> buildEntries() const;
    QString hostForServer(const QString& serverId) const;

    SecureServersRepository* m_serversRepository;
    QNetworkAccessManager* m_networkManager;
    QTimer* m_autoRefreshTimer;

    QMap<QString, int> m_pingResults;  // serverId -> ms
    int m_pendingReplies = 0;
};

#endif // PINGCONTROLLER_H
