package indexer

import log "github.com/sirupsen/logrus"

func (svc *Service) watchErrors() {
	for err := range svc.errChan {
		log.Infof("svc.watchErrors: %v", err)
	}
}
